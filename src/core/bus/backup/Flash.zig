const std = @import("std");

const Self = @This();

state: State,

id_mode: bool,
set_bank: bool,
prep_erase: bool,
prep_write: bool,

bank: u1,

const State = enum {
    Ready,
    Set,
    Command,
};

pub fn read(self: *const Self, buf: []u8, idx: usize) u8 {
    return buf[self.address() + idx];
}

pub fn write(self: *Self, buf: []u8, idx: usize, byte: u8) void {
    buf[self.address() + idx] = byte;
    self.prep_write = false;
}

pub fn create() Self {
    return .{
        .state = .Ready,
        .id_mode = false,
        .set_bank = false,
        .prep_erase = false,
        .prep_write = false,
        .bank = 0,
    };
}

pub fn handleCommand(self: *Self, buf: []u8, byte: u8) void {
    switch (byte) {
        0x90 => self.id_mode = true,
        0xF0 => self.id_mode = false,
        0xB0 => self.set_bank = true,
        0x80 => self.prep_erase = true,
        0x10 => {
            @memset(buf, 0xFF);
            self.prep_erase = false;
        },
        0xA0 => self.prep_write = true,
        else => std.debug.panic("Unhandled Flash Command: 0x{X:0>2}", .{byte}),
    }

    self.state = .Ready;
}

pub fn shouldEraseSector(self: *const Self, addr: usize, byte: u8) bool {
    return self.state == .Command and self.prep_erase and byte == 0x30 and addr & 0xFFF == 0x000;
}

pub fn erase(self: *Self, buf: []u8, sector: usize) void {
    const start = self.address() + (sector & 0xF000);

    @memset(buf[start..][0..0x1000], 0xFF);
    self.prep_erase = false;
    self.state = .Ready;
}

/// Base Address
inline fn address(self: *const Self) usize {
    return if (self.bank == 1) 0x10000 else @as(usize, 0);
}
