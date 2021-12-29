const std = @import("std");
const GamePak = @import("pak.zig").GamePak;

const Allocator = std.mem.Allocator;

pub const Bus = struct {
    pak: GamePak,

    pub fn withPak(alloc: Allocator, path: []const u8) !@This() {
        return @This(){
            .pak = try GamePak.fromPath(alloc, path),
        };
    }

    pub fn readWord(self: *const @This(), addr: u32) u32 {
        return self.pak.readWord(addr);
    }

    pub fn writeWord(_: *@This(), _: u32, _: u32) void {
        std.debug.panic("TODO: Implement Bus#writeWord", .{});
    }

    pub fn readHalfWord(self: *const @This(), addr: u32) u16 {
        return self.pak.readHalfWord(addr);
    }

    pub fn writeHalfWord(self: *@This(), addr: u32, halfword: u16) void {

        // TODO: Actually implement the memory mmap
        if (addr >= self.pak.buf.len) {
            return;
        }

        self.pak.writeHalfWord(addr, halfword);
    }

    pub fn readByte(self: *const @This(), addr: u32) u8 {
        return self.pak.readByte(addr);
    }

    pub fn writeByte(_: *@This(), _: u32, _: u8) void {
        std.debug.panic("TODO: Implement Bus#writeByte", .{});
    }
};
