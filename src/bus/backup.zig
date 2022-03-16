const std = @import("std");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Backup);

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

    pub fn init(alloc: Allocator, kind: BackupKind) !Self {
        const buf_len: usize = switch (kind) {
            .Sram => 0x8000, // 32K
            .Flash => 0x10000, // 64K
            .Flash1M => 0x20000, // 128K
            .Eeprom => 0x2000, // FIXME: We assume 8K here
        };

        const buf = try alloc.alloc(u8, buf_len);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .alloc = alloc,
            .kind = kind,
        };
    }

    pub fn guessKind(rom: []const u8) ?BackupKind {
        @setRuntimeSafety(false);

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
        self.alloc.free(self.buf);
    }

    pub fn get8(self: *const Self, idx: usize) u8 {
        // TODO: Implement Flash and EEPROM
        switch (self.kind) {
            .Flash => return switch (idx) {
                0x0000 => 0x32, // Panasonic manufacturer ID
                0x0001 => 0x1B, // Panasonic device ID
                else => self.buf[idx],
            },
            .Flash1M => return switch (idx) {
                0x0000 => 0x62, // Sanyo manufacturer ID
                0x0001 => 0x13, // Sanyo device ID
                else => self.buf[idx],
            },
            .Eeprom => return self.buf[idx],
            .Sram => return self.buf[idx & 0x7FFF], // 32K SRAM chips are repeated
        }
    }

    pub fn set8(self: *Self, idx: usize, byte: u8) void {
        self.buf[idx] = byte;
    }
};

const BackupKind = enum {
    Eeprom,
    Sram,
    Flash,
    Flash1M,
};

const Needle = struct {
    str: []const u8,
    kind: BackupKind,

    fn init(str: []const u8, kind: BackupKind) @This() {
        return .{
            .str = str,
            .kind = kind,
        };
    }
};
