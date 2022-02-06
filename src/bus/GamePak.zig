const std = @import("std");

const Allocator = std.mem.Allocator;
const Self = @This();

title: [12]u8,
buf: []u8,
alloc: Allocator,

const log = std.log.scoped(.GamePak);

pub fn init(alloc: Allocator, path: []const u8) !Self {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const len = try file.getEndPos();
    const buf = try file.readToEndAlloc(alloc, len);
    const title = parseTitle(buf);

    const pak = Self{ .buf = buf, .alloc = alloc, .title = title };
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
    if (lookupMaker(maker)) |c| log.info("Maker Code: {s}", .{c}) else log.info("Maker: {s}", .{maker});
}

fn parseTitle(buf: []u8) [12]u8 {
    return buf[0xA0..0xAC].*;
}

fn lookupMaker(slice: *const [2]u8) ?[]const u8 {
    return switch (std.mem.bytesToValue(u16, slice)) {
        0x3130 => "Nintendo",
        else => null,
    };
}

pub fn deinit(self: Self) void {
    self.alloc.free(self.buf);
}

pub fn get32(self: *const Self, idx: usize) u32 {
    return (@as(u32, self.get16(idx + 2)) << 16) | @as(u32, self.get16(idx));
}

pub fn get16(self: *const Self, idx: usize) u16 {
    return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
}

pub fn get8(self: *const Self, idx: usize) u8 {
    return self.buf[idx];
}
