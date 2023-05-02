const std = @import("std");

const Allocator = std.mem.Allocator;

const buf_len = 0x400;
const Self = @This();

buf: []u8,
allocator: Allocator,

pub fn read(self: *const Self, comptime T: type, address: usize) T {
    const addr = address & 0x3FF;

    return switch (T) {
        u32, u16, u8 => std.mem.readIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)]),
        else => @compileError("OAM: Unsupported read width"),
    };
}

pub fn write(self: *Self, comptime T: type, address: usize, value: T) void {
    const addr = address & 0x3FF;

    switch (T) {
        u32, u16 => std.mem.writeIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)], value),
        u8 => return, // 8-bit writes are explicitly ignored
        else => @compileError("OAM: Unsupported write width"),
    }
}

pub fn init(allocator: Allocator) !Self {
    const buf = try allocator.alloc(u8, buf_len);
    @memset(buf, 0);

    return Self{ .buf = buf, .allocator = allocator };
}

pub fn reset(self: *Self) void {
    @memset(self.buf, 0);
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.buf);
    self.* = undefined;
}
