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
        else => @compileError("PALRAM: Unsupported read width"),
    };
}

pub fn write(self: *Self, comptime T: type, address: usize, value: T) void {
    const addr = address & 0x3FF;

    switch (T) {
        u32, u16 => std.mem.writeIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)], value),
        u8 => {
            const align_addr = addr & ~@as(u32, 1); // Aligned to Halfword boundary
            std.mem.writeIntSliceLittle(u16, self.buf[align_addr..][0..@sizeOf(u16)], @as(u16, value) * 0x101);
        },
        else => @compileError("PALRAM: Unsupported write width"),
    }
}

pub fn init(allocator: Allocator) !Self {
    const buf = try allocator.alloc(u8, buf_len);
    std.mem.set(u8, buf, 0);

    return Self{ .buf = buf, .allocator = allocator };
}

pub fn reset(self: *Self) void {
    std.mem.set(u8, self.buf, 0);
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.buf);
    self.* = undefined;
}

pub inline fn backdrop(self: *const Self) u16 {
    return std.mem.readIntNative(u16, self.buf[0..2]);
}
