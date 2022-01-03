const std = @import("std");
const bitfield = @import("bitfield");

const Bitfield = bitfield.Bitfield;
const Bit = bitfield.Bit;

pub const Io = struct {
    dispcnt: Dispcnt,

    pub fn init() @This() {
        return .{
            .dispcnt = .{ .val = 0x0000_0000 },
        };
    }

    pub fn read32(self: *const @This(), addr: u32) u32 {
        return switch (addr) {
            0x0400_0000 => @as(u32, self.dispcnt.val),
            else => std.debug.panic("[I/O:32] tried to read from {X:}", .{addr}),
        };
    }

    pub fn read16(self: *const @This(), addr: u32) u16 {
        return switch (addr) {
            0x0400_0000 => self.dispcnt.val,
            else => std.debug.panic("[I/O:16] tried to read from {X:}", .{addr}),
        };
    }

    pub fn write16(self: *@This(), addr: u32, halfword: u16) void {
        switch (addr) {
            0x0400_0000 => self.dispcnt.val = halfword,
            else => std.debug.panic("[I/O:16] tried to write 0x{X:} to 0x{X:}", .{ halfword, addr }),
        }
    }

    pub fn read8(self: *const @This(), addr: u32) u8 {
        return switch (addr) {
            0x0400_0000 => @truncate(u8, self.dispcnt.val),
            else => std.debug.panic("[I/O:8] tried to read from {X:}", .{addr}),
        };
    }
};

const Dispcnt = extern union {
    bg_mode: Bitfield(u16, 0, 3),
    frame_select: Bit(u16, 4),
    hblank_interval_free: Bit(u16, 5),
    obj_mapping: Bit(u16, 6),
    forced_blank: Bit(u16, 7),
    bg_enable: Bitfield(u16, 8, 4),
    obj_enable: Bit(u16, 12),
    win_enable: Bitfield(u16, 13, 2),
    obj_win_enable: Bit(u16, 15),
    val: u16,
};
