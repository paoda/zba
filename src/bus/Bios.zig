const std = @import("std");

const Allocator = std.mem.Allocator;
const Self = @This();

buf: ?[]u8,
alloc: Allocator,

pub fn init(alloc: Allocator, maybe_path: ?[]const u8) !Self {
    var buf: ?[]u8 = null;
    if (maybe_path) |path| {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const len = try file.getEndPos();
        buf = try file.readToEndAlloc(alloc, len);
    }

    return Self{
        .buf = buf,
        .alloc = alloc,
    };
}

pub fn deinit(self: Self) void {
    if (self.buf) |buf| self.alloc.free(buf);
}

pub fn get32(self: *const Self, idx: usize) u32 {
    if (self.buf) |buf|
        return (@as(u32, buf[idx + 3]) << 24) | (@as(u32, buf[idx + 2]) << 16) | (@as(u32, buf[idx + 1]) << 8) | (@as(u32, buf[idx]));

    std.debug.panic("[CPU/BIOS:32] ZBA tried to read from 0x{X:0>8} but no BIOS was provided.", .{idx});
}

pub fn get16(self: *const Self, idx: usize) u16 {
    if (self.buf) |buf|
        return (@as(u16, buf[idx + 1]) << 8) | @as(u16, buf[idx]);

    std.debug.panic("[CPU/BIOS:16] ZBA tried to read from 0x{X:0>8} but no BIOS was provided.", .{idx});
}

pub fn get8(self: *const Self, idx: usize) u8 {
    if (self.buf) |buf|
        return buf[idx];

    std.debug.panic("[CPU/BIOS:8] ZBA tried to read from 0x{X:0>8} but no BIOS was provided.", .{idx});
}
