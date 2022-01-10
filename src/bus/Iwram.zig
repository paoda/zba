const std = @import("std");

const Allocator = std.mem.Allocator;
const Self = @This();

buf: []u8,
alloc: Allocator,

pub fn init(alloc: Allocator) !Self {
    return Self{
        .buf = try alloc.alloc(u8, 0x40000),
        .alloc = alloc,
    };
}

pub fn deinit(self: Self) void {
    self.alloc.free(self.buf);
}

pub fn get32(self: *const Self, idx: usize) u32 {
    return (@as(u32, self.get16(idx + 2)) << 16) | @as(u32, self.get16(idx));
}

pub fn set32(self: *Self, idx: usize, word: u32) void {
    self.set16(idx + 2, @truncate(u16, word >> 16));
    self.set16(idx, @truncate(u16, word));
}

pub fn get16(self: *const Self, idx: usize) u16 {
    return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
}

pub fn set16(self: *Self, idx: usize, halfword: u16) void {
    self.buf[idx + 1] = @truncate(u8, halfword >> 8);
    self.buf[idx] = @truncate(u8, halfword);
}

pub fn get8(self: *const Self, idx: usize) u8 {
    return self.buf[idx];
}

pub fn set8(self: *Self, idx: usize, byte: u8) void {
    self.buf[idx] = byte;
}
