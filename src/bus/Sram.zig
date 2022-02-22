const std = @import("std");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.SRAM);
const Self = @This();

buf: []u8,
alloc: Allocator,

pub fn init(alloc: Allocator) !Self {
    // FIXME: SRAM is more than just a 64KB block of memory
    const buf = try alloc.alloc(u8, 0x10000);
    std.mem.set(u8, buf, 0);

    return Self{
        .buf = buf,
        .alloc = alloc,
    };
}

pub fn deinit(self: Self) void {
    self.alloc.free(self.buf);
}

pub fn get8(self: *const Self, idx: usize) u8 {
    return self.buf[idx];
}

pub fn set8(self: *Self, idx: usize, byte: u8) void {
    self.buf[idx] = byte;
}
