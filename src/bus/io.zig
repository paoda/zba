const std = @import("std");

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Bus = @import("../Bus.zig");

pub const Io = struct {
    const Self = @This();

    /// Read / Write
    ime: bool,
    ie: InterruptEnable,
    irq: InterruptRequest,

    keyinput: KeyInput,

    pub fn init() Self {
        return .{
            .ime = false,
            .ie = .{ .raw = 0x0000 },
            .irq = .{ .raw = 0x0000 },
            .keyinput = .{ .raw = 0x03FF },
        };
    }
};

/// Read / Write
pub const DisplayControl = extern union {
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
pub const DisplayStatus = extern union {
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
pub const VCount = extern union {
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

/// Read Only
/// 0 = Pressed, 1 = Released
const KeyInput = extern union {
    a: Bit(u16, 0),
    b: Bit(u16, 1),
    select: Bit(u16, 2),
    start: Bit(u16, 3),
    right: Bit(u16, 4),
    left: Bit(u16, 5),
    up: Bit(u16, 6),
    down: Bit(u16, 7),
    shoulder_r: Bit(u16, 8),
    shoulder_l: Bit(u16, 9),
    raw: u16,
};

// Read / Write
pub const BackgroundControl = extern union {
    priority: Bitfield(u16, 0, 2),
    char_base: Bitfield(u16, 2, 2),
    mosaic_enable: Bit(u16, 6),
    colour_mode: Bit(u16, 7),
    screen_base: Bitfield(u16, 8, 5),
    display_overflow: Bit(u16, 13),
    size: Bitfield(u16, 14, 2),
    raw: u16,
};

/// Write Only
pub const BackgroundOffset = extern union {
    offset: Bitfield(u16, 0, 9),
    raw: u16,
};

/// Read / Write
const InterruptRequest = extern union {
    vblank: Bit(u16, 0),
    hblank: Bit(u16, 1),
    coincidence: Bit(u16, 2),
    tim0_overflow: Bit(u16, 3),
    tim1_overflow: Bit(u16, 4),
    tim2_overflow: Bit(u16, 5),
    tim3_overflow: Bit(u16, 6),
    serial: Bit(u16, 7),
    dma0: Bit(u16, 8),
    dma1: Bit(u16, 9),
    dma2: Bit(u16, 10),
    dma3: Bit(u16, 11),
    keypad: Bit(u16, 12),
    game_pak: Bit(u16, 13),
    raw: u16,
};

pub fn read32(bus: *const Bus, addr: u32) u32 {
    return switch (addr) {
        0x0400_0000 => bus.ppu.dispcnt.raw,
        0x0400_0004 => bus.ppu.dispstat.raw,
        0x0400_0006 => bus.ppu.vcount.raw,
        0x0400_0200 => bus.io.ie.raw,
        0x0400_0208 => @boolToInt(bus.io.ime),
        else => std.debug.panic("[I/O:32] tried to read from {X:}", .{addr}),
    };
}

pub fn write32(bus: *Bus, addr: u32, word: u32) void {
    switch (addr) {
        0x0400_0000 => bus.ppu.dispcnt.raw = @truncate(u16, word),
        0x0400_0010 => {
            bus.ppu.bg[0].hofs.raw = @truncate(u16, word);
            bus.ppu.bg[0].vofs.raw = @truncate(u16, word >> 16);
        },
        0x0400_0014 => {
            bus.ppu.bg[1].hofs.raw = @truncate(u16, word);
            bus.ppu.bg[1].vofs.raw = @truncate(u16, word >> 16);
        },
        0x0400_0018 => {
            bus.ppu.bg[2].hofs.raw = @truncate(u16, word);
            bus.ppu.bg[2].vofs.raw = @truncate(u16, word >> 16);
        },
        0x0400_001C => {
            bus.ppu.bg[3].hofs.raw = @truncate(u16, word);
            bus.ppu.bg[3].vofs.raw = @truncate(u16, word >> 16);
        },
        0x0400_0200 => bus.io.ie.raw = @truncate(u16, word),
        0x0400_0208 => bus.io.ime = word & 1 == 1,
        else => std.debug.panic("[I/O:32] tried to write 0x{X:} to 0x{X:}", .{ word, addr }),
    }
}

pub fn read16(bus: *const Bus, addr: u32) u16 {
    return switch (addr) {
        0x0400_0000 => bus.ppu.dispcnt.raw,
        0x0400_0004 => bus.ppu.dispstat.raw,
        0x0400_0006 => bus.ppu.vcount.raw,
        0x0400_0130 => bus.io.keyinput.raw,
        0x0400_0200 => bus.io.ie.raw,
        0x0400_0208 => @boolToInt(bus.io.ime),
        else => std.debug.panic("[I/O:16] tried to read from {X:}", .{addr}),
    };
}

pub fn write16(bus: *Bus, addr: u32, halfword: u16) void {
    switch (addr) {
        0x0400_0000 => bus.ppu.dispcnt.raw = halfword,
        0x0400_0004 => bus.ppu.dispstat.raw = halfword,
        0x0400_0008...0x0400_000F => bus.ppu.bg[addr & 0x7].cnt.raw = halfword,
        0x0400_0010 => bus.ppu.bg[0].hofs.raw = halfword, // TODO: Don't write out every HOFS / VOFS?
        0x0400_0012 => bus.ppu.bg[0].vofs.raw = halfword,
        0x0400_0014 => bus.ppu.bg[1].hofs.raw = halfword,
        0x0400_0016 => bus.ppu.bg[1].vofs.raw = halfword,
        0x0400_0018 => bus.ppu.bg[2].hofs.raw = halfword,
        0x0400_001A => bus.ppu.bg[2].vofs.raw = halfword,
        0x0400_001C => bus.ppu.bg[3].hofs.raw = halfword,
        0x0400_001E => bus.ppu.bg[3].vofs.raw = halfword,
        0x0400_0200 => bus.io.ie.raw = halfword,
        0x0400_0202 => bus.io.irq.raw = halfword,
        0x0400_0208 => bus.io.ime = halfword & 1 == 1,
        else => std.debug.panic("[I/O:16] tried to write 0x{X:} to 0x{X:}", .{ halfword, addr }),
    }
}

pub fn read8(bus: *const Bus, addr: u32) u8 {
    return switch (addr) {
        0x0400_0000 => @truncate(u8, bus.ppu.dispcnt.raw),
        0x0400_0004 => @truncate(u8, bus.ppu.dispstat.raw),
        0x0400_0200 => @truncate(u8, bus.io.ie.raw),
        0x0400_0006 => @truncate(u8, bus.ppu.vcount.raw),
        else => std.debug.panic("[I/O:8] tried to read from {X:}", .{addr}),
    };
}

pub fn write8(self: *Bus, addr: u32, byte: u8) void {
    switch (addr) {
        0x0400_0208 => self.io.ime = byte & 1 == 1,
        else => std.debug.panic("[I/0:8] tried to write 0x{X:} to 0x{X:}", .{ byte, addr }),
    }
}
