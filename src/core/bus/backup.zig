const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Backup);

const escape = @import("../util.zig").escape;
const asString = @import("../util.zig").asString;

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

    flash: Flash,
    eeprom: Eeprom,

    pub fn init(alloc: Allocator, kind: BackupKind, title: [12]u8, path: ?[]const u8) !Self {
        log.info("Kind: {}", .{kind});

        const buf_size: usize = switch (kind) {
            .Sram => 0x8000, // 32K
            .Flash => 0x10000, // 64K
            .Flash1M => 0x20000, // 128K
            .None, .Eeprom => 0, // EEPROM is handled upon first Read Request to it
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
            .eeprom = Eeprom.init(alloc),
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

        // FIXME: Don't rely on this lol
        if (std.mem.eql(u8, file_path[file_path.len - 12 .. file_path.len], "untitled.sav")) {
            return log.err("ROM header lacks title, no save loaded", .{});
        }

        const file: std.fs.File = try std.fs.openFileAbsolute(file_path, .{});
        const file_buf = try file.readToEndAlloc(self.alloc, try file.getEndPos());
        defer self.alloc.free(file_buf);

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

                    self.buf = try self.alloc.alloc(u8, file_buf.len);
                    std.mem.copy(u8, self.buf, file_buf);
                    return log.info("Loaded Save from {s}", .{file_path});
                }

                log.err("EEPROM can either be 0x200 bytes or 0x2000 byes, but {s} was {X:} bytes", .{
                    file_path,
                    file_buf.len,
                });
            },
            .None => return SaveError.UnsupportedBackupKind,
        }
    }

    fn getSaveFilePath(self: *const Self, path: []const u8) ![]const u8 {
        const filename = try self.getSaveFilename();
        defer self.alloc.free(filename);

        return try std.fs.path.join(self.alloc, &[_][]const u8{ path, filename });
    }

    fn getSaveFilename(self: *const Self) ![]const u8 {
        const title = asString(escape(self.title));
        const name = if (title.len != 0) title else "untitled";

        return try std.mem.concat(self.alloc, u8, &[_][]const u8{ name, ".sav" });
    }

    fn writeSaveToDisk(self: Self, path: []const u8) !void {
        const file_path = try self.getSaveFilePath(path);
        defer self.alloc.free(file_path);

        switch (self.kind) {
            .Sram, .Flash, .Flash1M, .Eeprom => {
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
            .Sram => return self.buf[addr & 0x7FFF], // 32K SRAM chip is mirrored
            .None, .Eeprom => return 0xFF,
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
            .Sram => self.buf[addr & 0x7FFF] = byte,
            .None, .Eeprom => {},
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

    fn shouldEraseSector(self: *const Self, addr: usize, byte: u8) bool {
        return self.state == .Command and self.prep_erase and byte == 0x30 and addr & 0xFFF == 0x000;
    }

    fn write(self: *Self, buf: []u8, idx: usize, byte: u8) void {
        buf[self.baseAddress() + idx] = byte;
        self.prep_write = false;
    }

    fn read(self: *const Self, buf: []u8, idx: usize) u8 {
        return buf[self.baseAddress() + idx];
    }

    fn eraseSector(self: *Self, buf: []u8, idx: usize) void {
        const start = self.baseAddress() + (idx & 0xF000);

        std.mem.set(u8, buf[start..][0..0x1000], 0xFF);
        self.prep_erase = false;
        self.state = .Ready;
    }

    inline fn baseAddress(self: *const Self) usize {
        return if (self.bank == 1) 0x10000 else @as(usize, 0);
    }
};

const FlashState = enum {
    Ready,
    Set,
    Command,
};

const Eeprom = struct {
    const Self = @This();

    addr: u14,

    kind: Kind,
    state: State,
    writer: Writer,
    reader: Reader,

    alloc: Allocator,

    const Kind = enum {
        Unknown,
        Small, // 512B
        Large, // 8KB
    };

    const State = enum {
        Ready,
        Read,
        Write,
        WriteTransfer,
        RequestEnd,
    };

    fn init(alloc: Allocator) Self {
        return .{
            .kind = .Unknown,
            .state = .Ready,
            .writer = Writer.init(),
            .reader = Reader.init(),
            .addr = 0,
            .alloc = alloc,
        };
    }

    pub fn read(self: *Self) u1 {
        return self.reader.read();
    }

    pub fn write(self: *Self, word_count: u16, buf: *[]u8, bit: u1) void {
        if (self.guessKind(word_count)) |found| {
            log.info("EEPROM Kind: {}", .{found});
            self.kind = found;

            // buf.len will not equal zero when a save file was found and loaded.
            // Right now, we assume that the save file is of the correct size which
            // isn't necessarily true, since we can't trust anything a user can influence
            // TODO: use ?[]u8 instead of a 0-sized slice?
            if (buf.len == 0) {
                const len: usize = switch (found) {
                    .Small => 0x200,
                    .Large => 0x2000,
                    else => unreachable,
                };

                buf.* = self.alloc.alloc(u8, len) catch |e| {
                    log.err("Failed to resize EEPROM buf to {} bytes", .{len});
                    std.debug.panic("EEPROM entered irrecoverable state {}", .{e});
                };
                std.mem.set(u8, buf.*, 0xFF);
            }
        }

        if (self.state == .RequestEnd) {
            if (bit != 0) log.debug("EEPROM Request did not end in 0u1. TODO: is this ok?", .{});
            self.state = .Ready;
            return;
        }

        switch (self.state) {
            .Ready => self.writer.requestWrite(bit),
            .Read, .Write => self.writer.addressWrite(self.kind, bit),
            .WriteTransfer => self.writer.dataWrite(bit),
            .RequestEnd => unreachable, // We return early just above this block
        }

        self.tick(buf.*);
    }

    fn guessKind(self: *const Self, word_count: u16) ?Kind {
        if (self.kind != .Unknown or self.state != .Read) return null;

        return switch (word_count) {
            17 => .Large,
            9 => .Small,
            else => blk: {
                log.err("Unexpected length of DMA3 Transfer upon initial EEPROM read: {}", .{word_count});
                break :blk null;
            },
        };
    }

    fn tick(self: *Self, buf: []u8) void {
        switch (self.state) {
            .Ready => {
                if (self.writer.len() == 2) {
                    const req = @intCast(u2, self.writer.finish());
                    switch (req) {
                        0b11 => self.state = .Read,
                        0b10 => self.state = .Write,
                        else => log.err("Unknown EEPROM Request 0b{b:0>2}", .{req}),
                    }
                }
            },
            .Read => {
                switch (self.kind) {
                    .Large => {
                        if (self.writer.len() == 14) {
                            const addr = @intCast(u10, self.writer.finish());
                            const value = std.mem.readIntSliceLittle(u64, buf[@as(u13, addr) * 8 ..][0..8]);

                            self.reader.configure(value);
                            self.state = .RequestEnd;
                        }
                    },
                    .Small => {
                        if (self.writer.len() == 6) {
                            // FIXME: Duplicated code from above
                            const addr = @intCast(u6, self.writer.finish());
                            const value = std.mem.readIntSliceLittle(u64, buf[@as(u13, addr) * 8 ..][0..8]);

                            self.reader.configure(value);
                            self.state = .RequestEnd;
                        }
                    },
                    else => log.err("Unable to calculate EEPROM read address. EEPROM size UNKNOWN", .{}),
                }
            },
            .Write => {
                switch (self.kind) {
                    .Large => {
                        if (self.writer.len() == 14) {
                            self.addr = @intCast(u10, self.writer.finish());
                            self.state = .WriteTransfer;
                        }
                    },
                    .Small => {
                        if (self.writer.len() == 6) {
                            self.addr = @intCast(u6, self.writer.finish());
                            self.state = .WriteTransfer;
                        }
                    },
                    else => log.err("Unable to calculate EEPROM write address. EEPROM size UNKNOWN", .{}),
                }
            },
            .WriteTransfer => {
                if (self.writer.len() == 64) {
                    std.mem.writeIntSliceLittle(u64, buf[self.addr * 8 ..][0..8], self.writer.finish());
                    self.state = .RequestEnd;
                }
            },
            .RequestEnd => unreachable, // We return early in write() if state is .RequestEnd
        }
    }

    const Reader = struct {
        const This = @This();

        data: u64,
        i: u8,
        enabled: bool,

        fn init() This {
            return .{
                .data = 0,
                .i = 0,
                .enabled = false,
            };
        }

        fn configure(self: *This, value: u64) void {
            self.data = value;
            self.i = 0;
            self.enabled = true;
        }

        fn read(self: *This) u1 {
            if (!self.enabled) return 1;

            const bit = if (self.i < 4) blk: {
                break :blk 0;
            } else blk: {
                const idx = @intCast(u6, 63 - (self.i - 4));
                break :blk @truncate(u1, self.data >> idx);
            };

            self.i = (self.i + 1) % (64 + 4);
            if (self.i == 0) self.enabled = false;

            return bit;
        }
    };

    const Writer = struct {
        const This = @This();

        data: u64,
        i: u8,

        fn init() This {
            return .{ .data = 0, .i = 0 };
        }

        fn requestWrite(self: *This, bit: u1) void {
            const idx = @intCast(u1, 1 - self.i);
            self.data = (self.data & ~(@as(u64, 1) << idx)) | (@as(u64, bit) << idx);
            self.i += 1;
        }

        fn addressWrite(self: *This, kind: Eeprom.Kind, bit: u1) void {
            if (kind == .Unknown) return;

            const size: u4 = switch (kind) {
                .Large => 13,
                .Small => 5,
                .Unknown => unreachable,
            };

            const idx = @intCast(u4, size - self.i);
            self.data = (self.data & ~(@as(u64, 1) << idx)) | (@as(u64, bit) << idx);
            self.i += 1;
        }

        fn dataWrite(self: *This, bit: u1) void {
            const idx = @intCast(u6, 63 - self.i);
            self.data = (self.data & ~(@as(u64, 1) << idx)) | (@as(u64, bit) << idx);
            self.i += 1;
        }

        fn len(self: *const This) u8 {
            return self.i;
        }

        fn finish(self: *This) u64 {
            defer self.reset();
            return self.data;
        }

        fn reset(self: *This) void {
            self.i = 0;
            self.data = 0;
        }
    };
};
