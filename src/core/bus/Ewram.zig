const std = @import("std");

const Allocator = std.mem.Allocator;
const ewram_size = 0x40000;
const Self = @This();

buf: []u8,
allocator: Allocator,

pub fn read(self: *const Self, comptime T: type, address: usize) T {
    const addr = address & 0x3FFFF;

    return switch (T) {
        u32, u16, u8 => std.mem.readInt(T, self.buf[addr..][0..@sizeOf(T)], .little),
        else => @compileError("EWRAM: Unsupported read width"),
    };
}

pub fn write(self: *const Self, comptime T: type, address: usize, value: T) void {
    const addr = address & 0x3FFFF;

    return switch (T) {
        u32, u16, u8 => std.mem.writeInt(T, self.buf[addr..][0..@sizeOf(T)], value, .little),
        else => @compileError("EWRAM: Unsupported write width"),
    };
}

pub fn init(allocator: Allocator) !Self {
    const buf = try allocator.alloc(u8, ewram_size);
    @memset(buf, 0);

    return Self{
        .buf = buf,
        .allocator = allocator,
    };
}

pub fn reset(self: *Self) void {
    @memset(self.buf, 0);
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.buf);
    self.* = undefined;
}
