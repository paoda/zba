const std = @import("std");

const Backup = @import("backup.zig").Backup;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.GamePak);

const intToBytes = @import("../util.zig").intToBytes;

const Self = @This();

title: [12]u8,
buf: []u8,
alloc: Allocator,
backup: Backup,

pub fn init(alloc: Allocator, rom_path: []const u8, save_path: ?[]const u8) !Self {
    const file = try std.fs.cwd().openFile(rom_path, .{});
    defer file.close();

    const file_buf = try file.readToEndAlloc(alloc, try file.getEndPos());
    const title = parseTitle(file_buf);
    const kind = Backup.guessKind(file_buf) orelse .None;

    const pak = Self{
        .buf = file_buf,
        .alloc = alloc,
        .title = title,
        .backup = try Backup.init(alloc, kind, title, save_path),
    };
    pak.parseHeader();

    return pak;
}

fn parseHeader(self: *const Self) void {
    const title = parseTitle(self.buf);
    const code = self.buf[0xAC..0xB0];
    const maker = self.buf[0xB0..0xB2];
    const version = self.buf[0xBC];

    log.info("Title: {s}", .{title});
    if (version != 0) log.info("Version: {}", .{version});
    log.info("Game Code: {s}", .{code});
    if (lookupMaker(maker)) |c| log.info("Maker: {s}", .{c}) else log.info("Maker Code: {s}", .{maker});
}

fn parseTitle(buf: []u8) [12]u8 {
    return buf[0xA0..0xAC].*;
}

fn lookupMaker(slice: *const [2]u8) ?[]const u8 {
    const id = @as(u16, slice[1]) << 8 | @as(u16, slice[0]);
    return switch (id) {
        0x3130 => "Nintendo",
        else => null,
    };
}

inline fn isLarge(self: *const Self) bool {
    return self.buf.len > 0x100_0000;
}

pub fn deinit(self: Self) void {
    self.alloc.free(self.buf);
    self.backup.deinit();
}

pub fn read(self: *Self, comptime T: type, address: u32) T {
    const addr = address & 0x1FF_FFFF;

    if (self.backup.kind == .Eeprom) {
        if (self.isLarge()) {
            // Addresses 0x1FF_FF00 to 0x1FF_FFFF are reserved from EEPROM accesses if
            // * Backup type is EEPROM
            // * Large ROM (Size is greater than 16MB)
            if (addr > 0x1FF_FEFF)
                return self.backup.eeprom.read();
        } else {
            // Addresses 0x0D00_0000 to 0x0DFF_FFFF are reserved for EEPROM accesses if
            // * Backup type is EEPROM
            // * Small ROM (less than 16MB)
            if (@truncate(u8, address >> 24) == 0x0D)
                return self.backup.eeprom.read();
        }
    }

    return switch (T) {
        u32 => (@as(T, self.get(addr + 3)) << 24) | (@as(T, self.get(addr + 2)) << 16) | (@as(T, self.get(addr + 1)) << 8) | (@as(T, self.get(addr))),
        u16 => (@as(T, self.get(addr + 1)) << 8) | @as(T, self.get(addr)),
        u8 => self.get(addr),
        else => @compileError("GamePak: Unsupported read width"),
    };
}

pub fn write(self: *Self, comptime T: type, word_count: u16, address: u32, value: T) void {
    const addr = address & 0x1FF_FFFF;

    if (self.backup.kind == .Eeprom) {
        const bit = @truncate(u1, value);

        if (self.isLarge()) {
            // Addresses 0x1FF_FF00 to 0x1FF_FFFF are reserved from EEPROM accesses if
            // * Backup type is EEPROM
            // * Large ROM (Size is greater than 16MB)
            if (addr > 0x1FF_FEFF)
                return self.backup.eeprom.write(word_count, &self.backup.buf, bit);
        } else {
            // Addresses 0x0D00_0000 to 0x0DFF_FFFF are reserved for EEPROM accesses if
            // * Backup type is EEPROM
            // * Small ROM (less than 16MB)
            if (@truncate(u8, address >> 24) == 0x0D)
                return self.backup.eeprom.write(word_count, &self.backup.buf, bit);
        }
    }

    switch (T) {
        u32 => switch (address) {
            0x0800_00C4 => log.err("Wrote {} 0x{X:} to I/O Port Data and Direction", .{ T, value }),
            0x0800_00C6 => log.err("Wrote {} 0x{X:} to I/O Port Direction and Control", .{ T, value }),
            else => {},
        },
        u16 => switch (address) {
            0x0800_00C4 => log.err("Wrote {} 0x{X:} to I/O Port Data", .{ T, value }),
            0x0800_00C6 => log.err("Wrote {} 0x{X:} to I/O Port Direction", .{ T, value }),
            0x0800_00C8 => log.err("Wrote {} 0x{X:} to I/O Port Control", .{ T, value }),
            else => {},
        },
        u8 => log.warn("Wrote {} 0x{X:} to 0x{X:0>8}, Ignored.", .{ T, value, address }),
        else => @compileError("GamePak: Unsupported write width"),
    }
}

fn get(self: *const Self, i: u32) u8 {
    @setRuntimeSafety(false);
    if (i < self.buf.len) return self.buf[i];

    const lhs = i >> 1 & 0xFFFF;
    return @truncate(u8, lhs >> 8 * @truncate(u5, i & 1));
}

test "OOB Access" {
    const title = .{ 'H', 'E', 'L', 'L', 'O', ' ', 'W', 'O', 'R', 'L', 'D', '!' };
    const alloc = std.testing.allocator;
    const pak = Self{
        .buf = &.{},
        .alloc = alloc,
        .title = title,
        .backup = try Backup.init(alloc, .None, title, null),
    };

    std.debug.assert(pak.get(0) == 0x00); // 0x0000
    std.debug.assert(pak.get(1) == 0x00);

    std.debug.assert(pak.get(2) == 0x01); // 0x0001
    std.debug.assert(pak.get(3) == 0x00);

    std.debug.assert(pak.get(4) == 0x02); // 0x0002
    std.debug.assert(pak.get(5) == 0x00);
}
