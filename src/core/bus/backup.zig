const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Backup);

const Eeprom = @import("backup/eeprom.zig").Eeprom;
const Flash = @import("backup/Flash.zig");

const escape = @import("../../util.zig").escape;
const span = @import("../../util.zig").span;

const Needle = struct { str: []const u8, kind: Backup.Kind };
const backup_kinds = [6]Needle{
    .{ .str = "EEPROM_V", .kind = .Eeprom },
    .{ .str = "SRAM_V", .kind = .Sram },
    .{ .str = "SRAM_F_V", .kind = .Sram },
    .{ .str = "FLASH_V", .kind = .Flash },
    .{ .str = "FLASH512_V", .kind = .Flash },
    .{ .str = "FLASH1M_V", .kind = .Flash1M },
};

const SaveError = error{Unsupported};

pub const Backup = struct {
    const Self = @This();

    buf: []u8,
    allocator: Allocator,
    kind: Kind,

    title: [12]u8,
    save_path: ?[]const u8,

    flash: Flash,
    eeprom: Eeprom,

    const Kind = enum {
        Eeprom,
        Sram,
        Flash,
        Flash1M,
        None,
    };

    pub fn read(self: *const Self, address: usize) u8 {
        const addr = address & 0xFFFF;

        switch (self.kind) {
            .Flash => {
                switch (addr) {
                    0x0000 => if (self.flash.id_mode) return 0x32, // Panasonic manufacturer ID
                    0x0001 => if (self.flash.id_mode) return 0x1B, // Panasonic device ID
                    else => {},
                }

                return self.flash.read(self.buf, addr);
            },
            .Flash1M => {
                switch (addr) {
                    0x0000 => if (self.flash.id_mode) return 0x62, // Sanyo manufacturer ID
                    0x0001 => if (self.flash.id_mode) return 0x13, // Sanyo device ID
                    else => {},
                }

                return self.flash.read(self.buf, addr);
            },
            .Sram => return self.buf[addr & 0x7FFF], // 32K SRAM chip is mirrored
            .None, .Eeprom => return 0xFF,
        }
    }

    pub fn write(self: *Self, address: usize, byte: u8) void {
        const addr = address & 0xFFFF;

        switch (self.kind) {
            .Flash, .Flash1M => {
                if (self.flash.prep_write) return self.flash.write(self.buf, addr, byte);
                if (self.flash.shouldEraseSector(addr, byte)) return self.flash.erase(self.buf, addr);

                switch (addr) {
                    0x0000 => if (self.kind == .Flash1M and self.flash.set_bank) {
                        self.flash.bank = @truncate(u1, byte);
                    },
                    0x5555 => {
                        if (self.flash.state == .Command) {
                            self.flash.handleCommand(self.buf, byte);
                        } else if (byte == 0xAA and self.flash.state == .Ready) {
                            self.flash.state = .Set;
                        } else if (byte == 0xF0) {
                            self.flash.state = .Ready;
                        }
                    },
                    0x2AAA => if (byte == 0x55 and self.flash.state == .Set) {
                        self.flash.state = .Command;
                    },
                    else => {},
                }
            },
            .Sram => self.buf[addr & 0x7FFF] = byte,
            .None, .Eeprom => {},
        }
    }

    pub fn init(allocator: Allocator, kind: Kind, title: [12]u8, path: ?[]const u8) !Self {
        log.info("Kind: {}", .{kind});

        const buf_size: usize = switch (kind) {
            .Sram => 0x8000, // 32K
            .Flash => 0x10000, // 64K
            .Flash1M => 0x20000, // 128K
            .None, .Eeprom => 0, // EEPROM is handled upon first Read Request to it
        };

        const buf = try allocator.alloc(u8, buf_size);
        std.mem.set(u8, buf, 0xFF);

        var backup = Self{
            .buf = buf,
            .allocator = allocator,
            .kind = kind,
            .title = title,
            .save_path = path,
            .flash = Flash.create(),
            .eeprom = Eeprom.create(allocator),
        };

        if (backup.save_path) |p| backup.readSave(allocator, p) catch |e| log.err("Failed to load save: {}", .{e});
        return backup;
    }

    pub fn deinit(self: *Self) void {
        if (self.save_path) |path| self.writeSave(self.allocator, path) catch |e| log.err("Failed to write save: {}", .{e});
        self.allocator.free(self.buf);
        self.* = undefined;
    }

    /// Guesses the Backup Kind of a GBA ROM
    pub fn guess(rom: []const u8) Kind {
        for (backup_kinds) |needle| {
            const needle_len = needle.str.len;

            var i: usize = 0;
            while ((i + needle_len) < rom.len) : (i += 1) {
                if (std.mem.eql(u8, needle.str, rom[i..][0..needle_len])) return needle.kind;
            }
        }

        return .None;
    }

    fn readSave(self: *Self, allocator: Allocator, path: []const u8) !void {
        const file_path = try self.savePath(allocator, path);
        defer allocator.free(file_path);

        const expected = "untitled.sav";
        if (std.mem.eql(u8, file_path[file_path.len - expected.len .. file_path.len], expected)) {
            return log.err("ROM header lacks title, no save loaded", .{});
        }

        const file: std.fs.File = try std.fs.openFileAbsolute(file_path, .{});
        const file_buf = try file.readToEndAlloc(allocator, try file.getEndPos());
        defer allocator.free(file_buf);

        switch (self.kind) {
            .Sram, .Flash, .Flash1M => {
                if (self.buf.len == file_buf.len) {
                    std.mem.copy(u8, self.buf, file_buf);
                    return log.info("Loaded Save from {s}", .{file_path});
                }

                log.err("{s} is {} bytes, but we expected {} bytes", .{ file_path, file_buf.len, self.buf.len });
            },
            .Eeprom => {
                if (file_buf.len == 0x200 or file_buf.len == 0x2000) {
                    self.eeprom.kind = if (file_buf.len == 0x200) .Small else .Large;

                    self.buf = try allocator.alloc(u8, file_buf.len);
                    std.mem.copy(u8, self.buf, file_buf);
                    return log.info("Loaded Save from {s}", .{file_path});
                }

                log.err("EEPROM can either be 0x200 bytes or 0x2000 byes, but {s} was {X:} bytes", .{
                    file_path,
                    file_buf.len,
                });
            },
            .None => return SaveError.Unsupported,
        }
    }

    fn savePath(self: *const Self, allocator: Allocator, path: []const u8) ![]const u8 {
        const filename = try self.saveName(allocator);
        defer allocator.free(filename);

        return try std.fs.path.join(allocator, &[_][]const u8{ path, filename });
    }

    fn saveName(self: *const Self, allocator: Allocator) ![]const u8 {
        const title_str = span(&escape(self.title));
        const name = if (title_str.len != 0) title_str else "untitled";

        return try std.mem.concat(allocator, u8, &[_][]const u8{ name, ".sav" });
    }

    fn writeSave(self: Self, allocator: Allocator, path: []const u8) !void {
        const file_path = try self.savePath(allocator, path);
        defer allocator.free(file_path);

        switch (self.kind) {
            .Sram, .Flash, .Flash1M, .Eeprom => {
                const file = try std.fs.createFileAbsolute(file_path, .{});
                defer file.close();

                try file.writeAll(self.buf);
                log.info("Wrote Save to {s}", .{file_path});
            },
            else => return SaveError.Unsupported,
        }
    }
};
