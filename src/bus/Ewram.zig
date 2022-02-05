const std = @import("std");

const Allocator = std.mem.Allocator;
const Self = @This();

buf: []u8,
alloc: Allocator,

pub fn init(alloc: Allocator) !Self {
    const buf = try alloc.alloc(u8, 0x8000);
    std.mem.set(u8, buf, 0);

    return Self{
        .buf = buf,
        .alloc = alloc,
    };
}

pub fn deinit(self: Self) void {
    self.alloc.free(self.buf);
}

pub fn get32(self: *const Self, idx: usize) u32 {
    return (@as(u32, self.buf[idx + 3]) << 24) | (@as(u32, self.buf[idx + 2]) << 16) | (@as(u32, self.buf[idx + 1]) << 8) | (@as(u32, self.buf[idx]));
}

pub fn set32(self: *Self, idx: usize, word: u32) void {
    self.buf[idx + 3] = @truncate(u8, word >> 24);
    self.buf[idx + 2] = @truncate(u8, word >> 16);
    self.buf[idx + 1] = @truncate(u8, word >> 8);
    self.buf[idx] = @truncate(u8, word);
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
