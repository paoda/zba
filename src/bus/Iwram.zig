const std = @import("std");

const Allocator = std.mem.Allocator;
const iwram_size = 0x8000;
const Self = @This();

buf: []u8,
alloc: Allocator,

pub fn init(alloc: Allocator) !Self {
    const buf = try alloc.alloc(u8, iwram_size);
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
    const addr = address & 0x7FFF;

    return switch (T) {
        u32 => (@as(u32, self.buf[addr + 3]) << 24) | (@as(u32, self.buf[addr + 2]) << 16) | (@as(u32, self.buf[addr + 1]) << 8) | (@as(u32, self.buf[addr])),
        u16 => (@as(u16, self.buf[addr + 1]) << 8) | @as(u16, self.buf[addr]),
        u8 => self.buf[addr],
        else => @compileError("IWRAM: Unsupported read width"),
    };
}

pub fn write(self: *const Self, comptime T: type, address: usize, value: T) void {
    const addr = address & 0x7FFF;

    return switch (T) {
        u32 => {
            self.buf[addr + 3] = @truncate(u8, value >> 24);
            self.buf[addr + 2] = @truncate(u8, value >> 16);
            self.buf[addr + 1] = @truncate(u8, value >> 8);
            self.buf[addr + 0] = @truncate(u8, value >> 0);
        },
        u16 => {
            self.buf[addr + 1] = @truncate(u8, value >> 8);
            self.buf[addr + 0] = @truncate(u8, value >> 0);
        },
        u8 => self.buf[addr] = value,
        else => @compileError("IWRAM: Unsupported write width"),
    };
}
