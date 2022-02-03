const std = @import("std");

const Allocator = std.mem.Allocator;
const Self = @This();

buf: []u8,
alloc: Allocator,

pub fn init(alloc: Allocator, path: []const u8) !Self {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const len = try file.getEndPos();

    return Self{
        .buf = try file.readToEndAlloc(alloc, len),
        .alloc = alloc,
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
