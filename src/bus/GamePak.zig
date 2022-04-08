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
    defer alloc.free(file_buf);

    const title = parseTitle(file_buf);
    const kind = Backup.guessKind(file_buf) orelse .Sram;

    const buf = try alloc.alloc(u8, 0x200_0000); // 32MiB

    // GamePak addressable space has known values if there's no cartridge inserted
    var i: usize = 0;
    while (i < buf.len) : (i += @sizeOf(u16)) {
        std.mem.copy(u8, buf[i..][0..2], &intToBytes(u16, @truncate(u16, i / 2)));
    }

    std.mem.copy(u8, buf[0..file_buf.len], file_buf[0..file_buf.len]); // Copy over ROM

    const pak = Self{
        .buf = buf,
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

pub fn deinit(self: Self) void {
    self.alloc.free(self.buf);
    self.backup.deinit();
}

pub fn read(self: *const Self, comptime T: type, address: u32) T {
    const addr = address & 0x1FF_FFFF;

    return switch (T) {
        u32 => (@as(T, self.buf[addr + 3]) << 24) | (@as(T, self.buf[addr + 2]) << 16) | (@as(T, self.buf[addr + 1]) << 8) | (@as(T, self.buf[addr])),
        u16 => (@as(T, self.buf[addr + 1]) << 8) | @as(T, self.buf[addr]),
        u8 => self.buf[addr],
        else => @compileError("GamePak: Unsupported read width"),
    };
}
