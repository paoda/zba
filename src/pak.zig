const std = @import("std");

const Allocator = std.mem.Allocator;

pub const GamePak = struct {
    buf: []u8,

    pub fn fromPath(alloc: Allocator, path: []const u8) !@This() {
        const file = try std.fs.cwd().openFile(path, .{ .read = true });
        defer file.close();

        const len = try file.getEndPos();

        return @This(){
            .buf = try file.readToEndAlloc(alloc, len),
        };
    }

    pub fn readWord(self: *const @This(), addr: u32) u32 {
        return (@as(u32, self.buf[addr + 3]) << 24) | (@as(u32, self.buf[addr + 2]) << 16) | (@as(u32, self.buf[addr + 1]) << 8) | (@as(u32, self.buf[addr]));
    }

    pub fn writeWord(self: *const @This(), addr: u32, word: u32) void {
        self.buf[addr + 3] = @truncate(u8, word >> 24);
        self.buf[addr + 2] = @truncate(u8, word >> 16);
        self.buf[addr + 1] = @truncate(u8, word >> 8);
        self.buf[addr] = @truncate(u8, word);
    }

    pub fn readHalfWord(self: *const @This(), addr: u32) u16 {
        return (@as(u16, self.buf[addr + 1]) << 8) | @as(u16, self.buf[addr]);
    }

    pub fn writeHalfWord(self: *@This(), addr: u32, halfword: u16) void {
        self.buf[addr + 1] = @truncate(u8, halfword >> 8);
        self.buf[addr] = @truncate(u8, halfword);
    }

    pub fn readByte(self: *const @This(), addr: u32) u8 {
        return self.buf[addr];
    }

    pub fn writeByte(self: *@This(), addr: u32, byte: u8) void {
        self.buf[addr] = byte;
    }
};
