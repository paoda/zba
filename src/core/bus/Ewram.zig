const std = @import("std");

const Allocator = std.mem.Allocator;
const ewram_size = 0x40000;
const Self = @This();

buf: []u8,
alloc: Allocator,

pub fn init(alloc: Allocator) !Self {
    const buf = try alloc.alloc(u8, ewram_size);
    std.mem.set(u8, buf, 0);

    return Self{
        .buf = buf,
        .alloc = alloc,
    };
}

pub fn deinit(self: Self) void {
    self.alloc.free(self.buf);
}

pub fn read(self: *const Self, comptime T: type, address: usize) T {
    const addr = address & 0x3FFFF;

    return switch (T) {
        u32, u16, u8 => std.mem.readIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)]),
        else => @compileError("EWRAM: Unsupported read width"),
    };
}

pub fn write(self: *const Self, comptime T: type, address: usize, value: T) void {
    const addr = address & 0x3FFFF;

    return switch (T) {
        u32, u16, u8 => std.mem.writeIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)], value),
        else => @compileError("EWRAM: Unsupported write width"),
    };
}
