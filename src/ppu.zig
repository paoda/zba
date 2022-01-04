const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Ppu = struct {
    vram: Vram,

    pub fn init(alloc: Allocator) !@This() {
        return @This(){
            .vram = try Vram.init(alloc),
        };
    }
};

const Vram = struct {
    buf: []u8,

    fn init(alloc: Allocator) !@This() {
        return @This(){
            .buf = try alloc.alloc(u8, 0x18000),
        };
    }

    pub inline fn get32(self: *const @This(), idx: usize) u32 {
        return (@as(u32, self.buf[idx + 3]) << 24) | (@as(u32, self.buf[idx + 2]) << 16) | (@as(u32, self.buf[idx + 1]) << 8) | (@as(u32, self.buf[idx]));
    }

    pub inline fn set32(self: *@This(), idx: usize, word: u32) void {
        self.buf[idx + 3] = @truncate(u8, word >> 24);
        self.buf[idx + 2] = @truncate(u8, word >> 16);
        self.buf[idx + 1] = @truncate(u8, word >> 8);
        self.buf[idx] = @truncate(u8, word);
    }

    pub inline fn get16(self: *const @This(), idx: usize) u16 {
        return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
    }

    pub inline fn set16(self: *@This(), idx: usize, halfword: u16) void {
        self.buf[idx + 1] = @truncate(u8, halfword >> 8);
        self.buf[idx] = @truncate(u8, halfword);
    }

    pub inline fn get8(self: *const @This(), idx: usize) u8 {
        return self.buf[idx];
    }
};
