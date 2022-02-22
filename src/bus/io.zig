const std = @import("std");

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Bus = @import("../Bus.zig");

const log = std.log.scoped(.@"I/O");

pub const Io = struct {
    const Self = @This();

    /// Read / Write
    ime: bool,
    ie: InterruptEnable,
    irq: InterruptRequest,
    postflg: PostFlag,
    is_halted: bool,

    keyinput: KeyInput,

    pub fn init() Self {
        return .{
            .ime = false,
            .ie = .{ .raw = 0x0000 },
            .irq = .{ .raw = 0x0000 },
            .postflg = .{ .raw = 0x00 },
            .keyinput = .{ .raw = 0x03FF },
            .is_halted = false,
        };
    }
};

pub fn read32(bus: *const Bus, addr: u32) u32 {
    return switch (addr) {
        0x0400_0000 => bus.ppu.dispcnt.raw,
        0x0400_0004 => bus.ppu.dispstat.raw,
        0x0400_0006 => bus.ppu.vcount.raw,
        0x0400_0200 => bus.io.ie.raw,
        0x0400_0208 => @boolToInt(bus.io.ime),
        0x0400_00C4 => failed_read("Tried to read word from DMA1CNT", .{}),
        0x0400_00D0 => failed_read("Tried to read word from DMA2CNT", .{}),
        else => std.debug.panic("Tried to read word from 0x{X:0>8}", .{addr}),
    };
}

pub fn write32(bus: *Bus, addr: u32, word: u32) void {
    switch (addr) {
        0x0400_0000 => bus.ppu.dispcnt.raw = @truncate(u16, word),
        0x0400_0004 => {
            bus.ppu.dispstat.raw = @truncate(u16, word);
            bus.ppu.vcount.raw = @truncate(u16, word >> 16);
        },
        0x0400_0008 => {
            bus.ppu.bg[0].cnt.raw = @truncate(u16, word);
            bus.ppu.bg[1].cnt.raw = @truncate(u16, word >> 16);
        },
        0x0400_000C => {
            bus.ppu.bg[2].cnt.raw = @truncate(u16, word);
            bus.ppu.bg[3].cnt.raw = @truncate(u16, word >> 16);
        },
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
        0x0400_00BC => log.warn("Wrote 0x{X:0>8} to DMA1SAD", .{word}),
        0x0400_00C0 => log.warn("Wrote 0x{X:0>8} to DMA1DAD", .{word}),
        0x0400_00C8 => log.warn("Wrote 0x{X:0>8} to DMA2SAD", .{word}),
        0x0400_00CC => log.warn("Wrote 0x{X:0>8} to DMA2DAD", .{word}),
        0x0400_0200 => bus.io.ie.raw = @truncate(u16, word),
        0x0400_0204 => log.warn("Wrote 0x{X:0>8} to WAITCNT", .{word}),
        0x0400_0208 => bus.io.ime = word & 1 == 1,
        else => std.debug.panic("Tried to write 0x{X:0>8} to 0x{X:0>8}", .{ word, addr }),
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
        0x0400_0102 => failed_read("Tried to read halfword from TM0CNT_H", .{}),
        0x0400_0106 => failed_read("Tried to read halfword from TM1CNT_H", .{}),
        0x0400_010A => failed_read("Tried to read halfword from TM2CNT_H", .{}),
        0x0400_010E => failed_read("Tried to read halfword from TM3CNT_H", .{}),
        0x0400_0204 => failed_read("Tried to read halfword from WAITCNT", .{}),
        else => std.debug.panic("Tried to read halfword from 0x{X:0>8}", .{addr}),
    };
}

pub fn write16(bus: *Bus, addr: u32, halfword: u16) void {
    switch (addr) {
        0x0400_0000 => bus.ppu.dispcnt.raw = halfword,
        0x0400_0004 => bus.ppu.dispstat.raw = halfword,
        0x0400_0008...0x0400_000F => bus.ppu.bg[addr & 0x3].cnt.raw = halfword,
        0x0400_0010 => bus.ppu.bg[0].hofs.raw = halfword, // TODO: Don't write out every HOFS / VOFS?
        0x0400_0012 => bus.ppu.bg[0].vofs.raw = halfword,
        0x0400_0014 => bus.ppu.bg[1].hofs.raw = halfword,
        0x0400_0016 => bus.ppu.bg[1].vofs.raw = halfword,
        0x0400_0018 => bus.ppu.bg[2].hofs.raw = halfword,
        0x0400_001A => bus.ppu.bg[2].vofs.raw = halfword,
        0x0400_001C => bus.ppu.bg[3].hofs.raw = halfword,
        0x0400_001E => bus.ppu.bg[3].vofs.raw = halfword,
        0x0400_0040 => log.warn("Wrote 0x{X:0>4} to WIN0H", .{halfword}),
        0x0400_0042 => log.warn("Wrote 0x{X:0>4} to WIN1H", .{halfword}),
        0x0400_0044 => log.warn("Wrote 0x{X:0>4} to WIN0V", .{halfword}),
        0x0400_0046 => log.warn("Wrote 0x{X:0>4} to WIN1V", .{halfword}),
        0x0400_0048 => log.warn("Wrote 0x{X:0>4} to WININ", .{halfword}),
        0x0400_004A => log.warn("Wrote 0x{X:0>4} to WINOUT", .{halfword}),
        0x0400_004C => log.warn("Wrote 0x{X:0>4} to MOSAIC", .{halfword}),
        0x0400_0050 => log.warn("Wrote 0x{X:0>4} to BLDCNT", .{halfword}),
        0x0400_0052 => log.warn("Wrote 0x{X:0>4} to BLDALPHA", .{halfword}),
        0x0400_0054 => log.warn("Wrote 0x{X:0>4} to BLDY", .{halfword}),
        0x0400_0080 => log.warn("Wrote 0x{X:0>4} to SOUNDCNT_L", .{halfword}),
        0x0400_0082 => log.warn("Wrote 0x{X:0>4} to SOUNDCNT_H", .{halfword}),
        0x0400_0084 => log.warn("Wrote 0x{X:0>4} to SOUNDCNT_X", .{halfword}),
        0x0400_00BA => log.warn("Wrote 0x{X:0>4} to DMA0CNT_H", .{halfword}),
        0x0400_00C6 => log.warn("Wrote 0x{X:0>4} to DMA1CNT_H", .{halfword}),
        0x0400_00D2 => log.warn("Wrote 0x{X:0>4} to DMA2CNT_H", .{halfword}),
        0x0400_00DE => log.warn("Wrote 0x{X:0>4} to DMA3CNT_H", .{halfword}),
        0x0400_0100 => log.warn("Wrote 0x{X:0>4} to TM0CNT_L", .{halfword}),
        0x0400_0102 => log.warn("Wrote 0x{X:0>4} to TM0CNT_H", .{halfword}),
        0x0400_0104 => log.warn("Wrote 0x{X:0>4} to TM1CNT_L", .{halfword}),
        0x0400_0106 => log.warn("Wrote 0x{X:0>4} to TM1CNT_H", .{halfword}),
        0x0400_0108 => log.warn("Wrote 0x{X:0>4} to TM2CNT_L", .{halfword}),
        0x0400_010A => log.warn("Wrote 0x{X:0>4} to TM2CNT_H", .{halfword}),
        0x0400_010C => log.warn("Wrote 0x{X:0>4} to TM3CNT_L", .{halfword}),
        0x0400_010E => log.warn("Wrote 0x{X:0>4} to TM3CNT_H", .{halfword}),
        0x0400_0120 => log.warn("Wrote 0x{X:0>4} to SIOMULTI0", .{halfword}),
        0x0400_0122 => log.warn("Wrote 0x{X:0>4} to SIOMULTI1", .{halfword}),
        0x0400_0124 => log.warn("Wrote 0x{X:0>4} to SIOMULTI2", .{halfword}),
        0x0400_0126 => log.warn("Wrote 0x{X:0>4} to SIOMULTI3", .{halfword}),
        0x0400_0128 => log.warn("Wrote 0x{X:0>4} to SIOCNT", .{halfword}),
        0x0400_012A => log.warn("Wrote 0x{X:0>4} to SIOMLT_SEND", .{halfword}),
        0x0400_0130 => log.warn("Wrote 0x{X:0>4} to KEYINPUT. Ignored", .{halfword}),
        0x0400_0132 => log.warn("Wrote 0x{X:0>4} to KEYCNT", .{halfword}),
        0x0400_0134 => log.warn("Wrote 0x{X:0>4} to RCNT", .{halfword}),
        0x0400_0200 => bus.io.ie.raw = halfword,
        0x0400_0202 => bus.io.irq.raw &= ~halfword,
        0x0400_0204 => log.warn("Wrote 0x{X:0>4} to WAITCNT", .{halfword}),
        0x0400_0208 => bus.io.ime = halfword & 1 == 1,
        else => std.debug.panic("Tried to write 0x{X:0>4} to 0x{X:0>8}", .{ halfword, addr }),
    }
}

pub fn read8(bus: *const Bus, addr: u32) u8 {
    return switch (addr) {
        0x0400_0000 => @truncate(u8, bus.ppu.dispcnt.raw),
        0x0400_0004 => @truncate(u8, bus.ppu.dispstat.raw),
        0x0400_0200 => @truncate(u8, bus.io.ie.raw),
        0x0400_0300 => bus.io.postflg.raw,
        0x0400_0006 => @truncate(u8, bus.ppu.vcount.raw),
        0x0400_0089 => failed_read("Tried to read (high) byte from SOUNDBIAS", .{}),
        else => std.debug.panic("Tried to read byte from 0x{X:0>8}", .{addr}),
    };
}

pub fn write8(self: *Bus, addr: u32, byte: u8) void {
    switch (addr) {
        0x0400_0208 => self.io.ime = byte & 1 == 1,
        0x0400_0301 => self.io.is_halted = byte >> 7 & 1 == 0, // TODO: Implement Stop?
        0x0400_0063 => log.warn("Tried to write 0x{X:0>2} to SOUND1CNT_H (high)", .{byte}),
        0x0400_0065 => log.warn("Tried to write 0x{X:0>2} to SOUND1CNT_X (high)", .{byte}),
        0x0400_0069 => log.warn("Tried to write 0x{X:0>2} to SOUND2CNT_L (high)", .{byte}),
        0x0400_006D => log.warn("Tried to write 0x{X:0>2} to SOUND2CNT_H (high)", .{byte}),
        0x0400_0070 => log.warn("Tried to write 0x{X:0>2} to SOUND3CNT_L (low)", .{byte}),
        0x0400_0079 => log.warn("Tried to write 0x{X:0>2} to SOUND4CNT_L (high)", .{byte}),
        0x0400_007D => log.warn("Tried to write 0x{X:0>2} to SOUND4CNT_H (high)", .{byte}),
        0x0400_0080 => log.warn("Tried to write 0x{X:0>2} to SOUNDCNT_L (low)", .{byte}),
        0x0400_0089 => log.warn("Tried to write 0x{X:0>2} to SOUNDBIAS (high)", .{byte}),
        else => std.debug.panic("Tried to write 0x{X:0>2} to 0x{X:0>8}", .{ byte, addr }),
    }
}

fn failed_read(comptime format: []const u8, args: anytype) u8 {
    log.warn(format, args);
    return 0;
}

/// Read / Write 
pub const PostFlag = extern union {
    /// 0 if First Boot, 1 if a Reset has been done
    not_first_boot: Bit(u8, 0),
    raw: u8,
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
