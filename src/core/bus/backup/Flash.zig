const std = @import("std");

const Self = @This();

state: State,
kind: Kind,
bank: u1,

id_mode: bool,
set_bank: bool,
prep_erase: bool,
prep_write: bool,

const Kind = enum { Flash, Flash1M };
const State = enum { Ready, Set, Command };

pub fn read(self: *const Self, buf: []u8, address: u32) u8 {
    const addr = address & 0xFFFF;

    if (self.kind == .Flash1M) {
        switch (addr) {
            0x0000 => if (self.id_mode) return 0x32, // Panasonic manufacturer ID
            0x0001 => if (self.id_mode) return 0x1B, // Panasonic device ID
            else => {},
        }
    } else {
        switch (addr) {
            0x0000 => if (self.id_mode) return 0x62, // Sanyo manufacturer ID
            0x0001 => if (self.id_mode) return 0x13, // Sanyo device ID
            else => {},
        }
    }

    return buf[self.baseAddress() + addr];
}

pub fn write(self: *Self, buf: []u8, address: u32, value: u8) void {
    const addr = address & 0xFFFF;

    if (self.prep_write) return self._write(buf, addr, value);
    if (self.shouldEraseSector(addr, value)) return self.erase(buf, addr);

    switch (addr) {
        0x0000 => if (self.kind == .Flash1M and self.set_bank) {
            self.bank = @truncate(u1, value);
        },
        0x5555 => {
            if (self.state == .Command) {
                self.handleCommand(buf, value);
            } else if (value == 0xAA and self.state == .Ready) {
                self.state = .Set;
            } else if (value == 0xF0) {
                self.state = .Ready;
            }
        },
        0x2AAA => if (value == 0x55 and self.state == .Set) {
            self.state = .Command;
        },
        else => {},
    }
}

fn _write(self: *Self, buf: []u8, idx: usize, byte: u8) void {
    buf[self.baseAddress() + idx] = byte;
    self.prep_write = false;
}

pub fn create(kind: Kind) !Self {
    return .{
        .state = .Ready,
        .kind = kind,
        .bank = 0,

        .id_mode = false,
        .set_bank = false,
        .prep_erase = false,
        .prep_write = false,
    };
}

fn handleCommand(self: *Self, buf: []u8, value: u8) void {
    switch (value) {
        0x90 => self.id_mode = true,
        0xF0 => self.id_mode = false,
        0xB0 => self.set_bank = true,
        0x80 => self.prep_erase = true,
        0x10 => {
            std.mem.set(u8, buf, 0xFF);
            self.prep_erase = false;
        },
        0xA0 => self.prep_write = true,
        else => std.debug.panic("Unhandled Flash Command: 0x{X:0>2}", .{value}),
    }

    self.state = .Ready;
}

fn shouldEraseSector(self: *const Self, addr: usize, byte: u8) bool {
    return self.state == .Command and self.prep_erase and byte == 0x30 and addr & 0xFFF == 0x000;
}

fn erase(self: *Self, buf: []u8, sector: usize) void {
    const start = self.baseAddress() + (sector & 0xF000);

    std.mem.set(u8, buf[start..][0..0x1000], 0xFF);
    self.prep_erase = false;
    self.state = .Ready;
}

/// Base Address
inline fn baseAddress(self: *const Self) usize {
    return if (self.bank == 1) 0x10000 else @as(usize, 0);
}
