const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Bios = struct {
    buf: []u8,

    pub fn init(alloc: Allocator, path: []const u8) !@This() {
        const file = try std.fs.cwd().openFile(path, .{ .read = true });
        defer file.close();

        const len = try file.getEndPos();

        return @This(){
            .buf = try file.readToEndAlloc(alloc, len),
        };
    }

    pub inline fn get32(self: *const @This(), idx: usize) u32 {
        std.debug.panic("[BIOS] TODO: BIOS is not implemented", .{});
        return (@as(u32, self.buf[idx + 3]) << 24) | (@as(u32, self.buf[idx + 2]) << 16) | (@as(u32, self.buf[idx + 1]) << 8) | (@as(u32, self.buf[idx]));
    }

    pub inline fn get16(self: *const @This(), idx: usize) u16 {
        std.debug.panic("[BIOS] TODO: BIOS is not implemented", .{});
        return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
    }

    pub inline fn get8(self: *const @This(), idx: usize) u8 {
        std.debug.panic("[BIOS] TODO: BIOS is not implemented", .{});
        return self.buf[idx];
    }
};
