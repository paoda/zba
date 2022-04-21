const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Backup);

const correctTitle = @import("../util.zig").correctTitle;
const safeTitle = @import("../util.zig").safeTitle;

const backup_kinds = [5]Needle{
    .{ .str = "EEPROM_V", .kind = .Eeprom },
    .{ .str = "SRAM_V", .kind = .Sram },
    .{ .str = "FLASH_V", .kind = .Flash },
    .{ .str = "FLASH512_V", .kind = .Flash },
    .{ .str = "FLASH1M_V", .kind = .Flash1M },
};

pub const Backup = struct {
    const Self = @This();

    buf: []u8,
    alloc: Allocator,
    kind: BackupKind,

    title: [12]u8,
    save_path: ?[]const u8,

    // TODO: Implement EEPROM
    flash: Flash,

    pub fn init(alloc: Allocator, kind: BackupKind, title: [12]u8, path: ?[]const u8) !Self {
        log.info("Kind: {}", .{kind});

        const buf_size: usize = switch (kind) {
            .Sram => 0x8000, // 32K
            .Flash => 0x10000, // 64K
            .Flash1M => 0x20000, // 128K
            .Eeprom => 0x2000, // FIXME: We assume 8K here
            .None => 0,
        };

        const buf = try alloc.alloc(u8, buf_size);
        std.mem.set(u8, buf, 0xFF);

        var backup = Self{
            .buf = buf,
            .alloc = alloc,
            .kind = kind,
            .title = title,
            .save_path = path,
            .flash = Flash.init(),
        };

        if (backup.save_path) |p| backup.loadSaveFromDisk(p) catch |e| log.err("Failed to load save: {}", .{e});
        return backup;
    }

    pub fn guessKind(rom: []const u8) ?BackupKind {
        for (backup_kinds) |needle| {
            const needle_len = needle.str.len;

            var i: usize = 0;
            while ((i + needle_len) < rom.len) : (i += 1) {
                if (std.mem.eql(u8, needle.str, rom[i..][0..needle_len])) return needle.kind;
            }
        }

        return null;
    }

    pub fn deinit(self: Self) void {
        if (self.save_path) |path| self.writeSaveToDisk(path) catch |e| log.err("Failed to write save: {}", .{e});
        self.alloc.free(self.buf);
    }

    fn loadSaveFromDisk(self: *Self, path: []const u8) !void {
        const file_path = try self.getSaveFilePath(path);
        defer self.alloc.free(file_path);

        const file: std.fs.File = try std.fs.openFileAbsolute(file_path, .{});
        const file_buf = try file.readToEndAlloc(self.alloc, try file.getEndPos());
        defer self.alloc.free(file_buf);

        switch (self.kind) {
            .Sram, .Flash, .Flash1M => {
                if (self.buf.len == file_buf.len) {
                    std.mem.copy(u8, self.buf, file_buf);
                    return log.info("Loaded Save from {s}", .{file_path});
                }

                log.debug("{s} is {} bytes, but we expected {} bytes", .{ file_path, file_buf.len, self.buf.len });
            },
            else => return SaveError.UnsupportedBackupKind,
        }
    }

    fn getSaveFilePath(self: *const Self, path: []const u8) ![]const u8 {
        const filename = try self.getSaveFilename();
        defer self.alloc.free(filename);

        return try std.fs.path.join(self.alloc, &[_][]const u8{ path, filename });
    }

    fn getSaveFilename(self: *const Self) ![]const u8 {
        const title = correctTitle(safeTitle(self.title));
        return try std.mem.concat(self.alloc, u8, &[_][]const u8{ title, ".sav" });
    }

    fn writeSaveToDisk(self: Self, path: []const u8) !void {
        const file_path = try self.getSaveFilePath(path);
        defer self.alloc.free(file_path);

        switch (self.kind) {
            .Sram, .Flash, .Flash1M => {
                const file = try std.fs.createFileAbsolute(file_path, .{});
                defer file.close();

                try file.writeAll(self.buf);
                log.info("Wrote Save to {s}", .{file_path});
            },
            else => return SaveError.UnsupportedBackupKind,
        }
    }

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
            .Eeprom => return self.buf[addr],
            .Sram => return self.buf[addr & 0x7FFF], // 32K SRAM chip is mirrored
            .None => return 0xFF,
        }
    }

    pub fn write(self: *Self, address: usize, byte: u8) void {
        const addr = address & 0xFFFF;

        switch (self.kind) {
            .Flash, .Flash1M => {
                if (self.flash.prep_write) return self.flash.write(self.buf, addr, byte);
                if (self.flash.shouldEraseSector(addr, byte)) return self.flash.eraseSector(self.buf, addr);

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
            .Eeprom => self.buf[addr] = byte,
            .Sram => self.buf[addr & 0x7FFF] = byte,
            .None => {},
        }
    }
};

const BackupKind = enum {
    Eeprom,
    Sram,
    Flash,
    Flash1M,
    None,
};

const Needle = struct {
    const Self = @This();

    str: []const u8,
    kind: BackupKind,

    fn init(str: []const u8, kind: BackupKind) Self {
        return .{
            .str = str,
            .kind = kind,
        };
    }
};

const SaveError = error{
    UnsupportedBackupKind,
};

const Flash = struct {
    const Self = @This();

    state: FlashState,

    id_mode: bool,
    set_bank: bool,
    prep_erase: bool,
    prep_write: bool,

    bank: u1,

    fn init() Self {
        return .{
            .state = .Ready,
            .id_mode = false,
            .set_bank = false,
            .prep_erase = false,
            .prep_write = false,
            .bank = 0,
        };
    }

    fn handleCommand(self: *Self, buf: []u8, byte: u8) void {
        switch (byte) {
            0x90 => self.id_mode = true,
            0xF0 => self.id_mode = false,
            0xB0 => self.set_bank = true,
            0x80 => self.prep_erase = true,
            0x10 => {
                std.mem.set(u8, buf, 0xFF);
                self.prep_erase = false;
            },
            0xA0 => self.prep_write = true,
            else => std.debug.panic("Unhandled Flash Command: 0x{X:0>2}", .{byte}),
        }

        self.state = .Ready;
    }

    fn shouldEraseSector(self: *const Self, idx: usize, byte: u8) bool {
        return self.prep_erase and idx & 0xFFF == 0x000 and byte == 0x30;
    }

    fn write(self: *Self, buf: []u8, idx: usize, byte: u8) void {
        buf[idx + if (self.bank == 1) 0x1000 else @as(usize, 0)] = byte;
        self.prep_write = false;
    }

    fn read(self: *const Self, buf: []u8, idx: usize) u8 {
        return buf[idx + if (self.bank == 1) 0x1000 else @as(usize, 0)];
    }

    fn eraseSector(self: *Self, buf: []u8, idx: usize) void {
        const start = (idx & 0xF000) + if (self.bank == 1) 0x1000 else @as(usize, 0);

        std.mem.set(u8, buf[start..][0..0x1000], 0xFF);
        self.prep_erase = false;
        self.state = .Ready;
    }
};

const FlashState = enum {
    Ready,
    Set,
    Command,
};
