const std = @import("std");

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;

pub const Io = struct {
    const Self = @This();

    dispcnt: DisplayControl,
    dispstat: DisplayStatus,
    vcount: VCount,
    /// Read / Write
    ime: bool,
    ie: InterruptEnable,

    pub fn init() Self {
        return .{
            .dispcnt = .{ .raw = 0x0000_0000 },
            .dispstat = .{ .raw = 0x0000_0000 },
            .vcount = .{ .raw = 0x0000_0000 },
            .ime = false,
            .ie = .{ .raw = 0x0000_0000 },
        };
    }

    pub fn read32(self: *const Self, addr: u32) u32 {
        return switch (addr) {
            0x0400_0000 => @as(u32, self.dispcnt.raw),
            0x0400_0004 => @as(u32, self.dispstat.raw),
            0x0400_0006 => @as(u32, self.vcount.raw),
            0x0400_0200 => @as(u32, self.ie.raw),
            0x0400_0208 => @boolToInt(self.ime),
            else => std.debug.panic("[I/O:32] tried to read from {X:}", .{addr}),
        };
    }

    pub fn write32(self: *Self, addr: u32, word: u32) void {
        switch (addr) {
            0x0400_0200 => self.ie.raw = @truncate(u16, word),
            0x0400_0208 => self.ime = word & 1 == 1,
            else => std.debug.panic("[I/O:32] tried to write 0x{X:} to 0x{X:}", .{ word, addr }),
        }
    }

    pub fn read16(self: *const Self, addr: u32) u16 {
        return switch (addr) {
            0x0400_0000 => self.dispcnt.raw,
            0x0400_0004 => self.dispstat.raw,
            0x0400_0006 => self.vcount.raw,
            0x0400_0200 => self.ie.raw,
            0x0400_0208 => @boolToInt(self.ime),
            else => std.debug.panic("[I/O:16] tried to read from {X:}", .{addr}),
        };
    }

    pub fn write16(self: *Self, addr: u32, halfword: u16) void {
        switch (addr) {
            0x0400_0000 => self.dispcnt.raw = halfword,
            0x0400_0004 => self.dispstat.raw = halfword,
            0x0400_0200 => self.ie.raw = halfword,
            0x0400_0208 => self.ime = halfword & 1 == 1,
            else => std.debug.panic("[I/O:16] tried to write 0x{X:} to 0x{X:}", .{ halfword, addr }),
        }
    }

    pub fn read8(self: *const Self, addr: u32) u8 {
        return switch (addr) {
            0x0400_0000 => @truncate(u8, self.dispcnt.raw),
            0x0400_0004 => @truncate(u8, self.dispstat.raw),
            0x0400_0200 => @truncate(u8, self.ie.raw),
            0x0400_0006 => @truncate(u8, self.vcount.raw),
            else => std.debug.panic("[I/O:8] tried to read from {X:}", .{addr}),
        };
    }

    pub fn write8(_: *Self, addr: u32, byte: u8) void {
        std.debug.panic("[I/0:8] tried to write 0x{X:} to 0x{X:}", .{ byte, addr });
    }
};

/// Read / Write
const DisplayControl = extern union {
    bg_mode: Bitfield(u16, 0, 3),
    frame_select: Bit(u16, 4),
    hblank_interval_free: Bit(u16, 5),
    obj_mapping: Bit(u16, 6),
    forced_blank: Bit(u16, 7),
    bg_enable: Bitfield(u16, 8, 4),
    obj_enable: Bit(u16, 12),
    win_enable: Bitfield(u16, 13, 2),
    obj_win_enable: Bit(u16, 15),
    raw: u16,
};

/// Read / Write
const DisplayStatus = extern union {
    vblank: Bit(u16, 0),
    hblank: Bit(u16, 1),
    coincidence: Bit(u16, 2),
    vblank_irq: Bit(u16, 3),
    hblank_irq: Bit(u16, 4),
    vcount_irq: Bit(u16, 5),
    vcount_trigger: Bitfield(u16, 8, 8),
    raw: u16,
};

/// Read Only
const VCount = extern union {
    scanline: Bitfield(u16, 0, 8),
    raw: u16,
};

/// Read / Write
const InterruptEnable = extern union {
    vblank: Bit(u16, 0),
    hblank: Bit(u16, 1),
    coincidence: Bit(u16, 2),
    tm0_overflow: Bit(u16, 3),
    tm1_overflow: Bit(u16, 4),
    tm2_overflow: Bit(u16, 5),
    tm3_overflow: Bit(u16, 6),
    serial: Bit(u16, 7),
    dma0: Bit(u16, 8),
    dma1: Bit(u16, 9),
    dma2: Bit(u16, 10),
    dma3: Bit(u16, 11),
    keypad: Bit(u16, 12),
    game_pak: Bit(u16, 13),
    raw: u16,
};
