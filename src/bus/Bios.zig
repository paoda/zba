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

pub fn read(self: *const Self, comptime T: type, addr: usize) T {
    if (self.buf) |buf| {
        return switch (T) {
            u32 => (@as(u32, buf[addr + 3]) << 24) | (@as(u32, buf[addr + 2]) << 16) | (@as(u32, buf[addr + 1]) << 8) | (@as(u32, buf[addr])),
            u16 => (@as(u16, buf[addr + 1]) << 8) | @as(u16, buf[addr]),
            u8 => buf[addr],
            else => @compileError("BIOS: Unsupported read width"),
        };
    }

    std.debug.panic("[BIOS] ZBA tried to read {} from 0x{X:0>8} but not BIOS was present", .{ T, addr });
}
