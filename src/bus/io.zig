const std = @import("std");

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Bus = @import("../Bus.zig");
const DmaController = @import("dma.zig").DmaController;
const Scheduler = @import("../scheduler.zig").Scheduler;

const panic_on_und_io: bool = false;

const log = std.log.scoped(.@"I/O");

pub const Io = struct {
    const Self = @This();

    /// Read / Write
    ime: bool,
    ie: InterruptEnable,
    irq: InterruptRequest,
    postflg: PostFlag,
    haltcnt: HaltControl,
    keyinput: KeyInput,

    pub fn init() Self {
        return .{
            .ime = false,
            .ie = .{ .raw = 0x0000 },
            .irq = .{ .raw = 0x0000 },
            .keyinput = .{ .raw = 0x03FF },
            .postflg = .FirstBoot,
            .haltcnt = .Execute,
        };
    }

    fn setIrqs(self: *Io, word: u32) void {
        self.ie.raw = @truncate(u16, word);
        self.irq.raw &= ~@truncate(u16, word >> 16);
    }
};

pub fn read32(bus: *const Bus, addr: u32) u32 {
    return switch (addr) {
        // Display
        0x0400_0000 => bus.ppu.dispcnt.raw,
        0x0400_0004 => @as(u32, bus.ppu.vcount.raw) << 16 | bus.ppu.dispstat.raw,
        0x0400_0006 => @as(u32, bus.ppu.bg[0].cnt.raw) << 16 | bus.ppu.vcount.raw,

        // DMA Transfers
        0x0400_00B8 => @as(u32, bus.dma._0.cnt.raw) << 16,
        0x0400_00C4 => @as(u32, bus.dma._1.cnt.raw) << 16,
        0x0400_00D0 => @as(u32, bus.dma._1.cnt.raw) << 16,
        0x0400_00DC => @as(u32, bus.dma._3.cnt.raw) << 16,

        // Timers
        0x0400_0100 => @as(u32, bus.tim._0.cnt.raw) << 16 | bus.tim._0.counter(),
        0x0400_0104 => @as(u32, bus.tim._1.cnt.raw) << 16 | bus.tim._1.counter(),
        0x0400_0108 => @as(u32, bus.tim._2.cnt.raw) << 16 | bus.tim._2.counter(),
        0x0400_010C => @as(u32, bus.tim._3.cnt.raw) << 16 | bus.tim._3.counter(),

        // Interrupts
        0x0400_0200 => @as(u32, bus.io.irq.raw) << 16 | bus.io.ie.raw,
        0x0400_0208 => @boolToInt(bus.io.ime),
        else => undRead("Tried to read word from 0x{X:0>8}", .{addr}),
    };
}

pub fn write32(bus: *Bus, addr: u32, word: u32) void {
    switch (addr) {
        // Display
        0x0400_0000 => bus.ppu.dispcnt.raw = @truncate(u16, word),
        0x0400_0004 => {
            bus.ppu.dispstat.raw = @truncate(u16, word);
            bus.ppu.vcount.raw = @truncate(u16, word >> 16);
        },
        0x0400_0008 => bus.ppu.setAdjCnts(0, word),
        0x0400_000C => bus.ppu.setAdjCnts(2, word),
        0x0400_0010 => bus.ppu.setBgOffsets(0, word),
        0x0400_0014 => bus.ppu.setBgOffsets(1, word),
        0x0400_0018 => bus.ppu.setBgOffsets(2, word),
        0x0400_001C => bus.ppu.setBgOffsets(3, word),

        // Sound
        0x0400_00A0 => log.warn("Wrote 0x{X:0>8} to FIFO_A", .{word}),
        0x0400_00A4 => log.warn("Wrote 0x{X:0>8} to FIFO_B", .{word}),

        // DMA Transfers
        0x0400_00B0 => bus.dma._0.writeSad(word),
        0x0400_00B4 => bus.dma._0.writeDad(word),
        0x0400_00B8 => bus.dma._0.writeCnt(word),
        0x0400_00BC => bus.dma._1.writeSad(word),
        0x0400_00C0 => bus.dma._1.writeDad(word),
        0x0400_00C4 => bus.dma._1.writeCnt(word),
        0x0400_00C8 => bus.dma._2.writeSad(word),
        0x0400_00CC => bus.dma._2.writeDad(word),
        0x0400_00D0 => bus.dma._2.writeCnt(word),
        0x0400_00D4 => bus.dma._3.writeSad(word),
        0x0400_00D8 => bus.dma._3.writeDad(word),
        0x0400_00DC => bus.dma._3.writeCnt(word),

        // Timers
        0x0400_0100 => bus.tim._0.writeCnt(word),
        0x0400_0104 => bus.tim._1.writeCnt(word),
        0x0400_0108 => bus.tim._2.writeCnt(word),
        0x0400_010C => bus.tim._3.writeCnt(word),

        // Serial Communication 1
        0x0400_0120 => log.warn("Wrote 0x{X:0>8} to SIODATA32", .{word}),

        // Interrupts
        0x0400_0200 => bus.io.setIrqs(word),
        0x0400_0204 => log.warn("Wrote 0x{X:0>8} to WAITCNT", .{word}),
        0x0400_0208 => bus.io.ime = word & 1 == 1,
        else => undWrite("Tried to write 0x{X:0>8} to 0x{X:0>8}", .{ word, addr }),
    }
}

pub fn read16(bus: *const Bus, addr: u32) u16 {
    return switch (addr) {
        // Display
        0x0400_0000 => bus.ppu.dispcnt.raw,
        0x0400_0004 => bus.ppu.dispstat.raw,
        0x0400_0006 => bus.ppu.vcount.raw,

        // Sound
        0x0400_0088 => bus.apu.bias.raw,

        // DMA Transfers
        0x0400_00BA => bus.dma._0.cnt.raw,

        // Timers
        0x0400_0100 => bus.tim._0.counter(),
        0x0400_0102 => bus.tim._0.cnt.raw,
        0x0400_0104 => bus.tim._1.counter(),
        0x0400_0106 => bus.tim._1.cnt.raw,
        0x0400_0108 => bus.tim._2.counter(),
        0x0400_010A => bus.tim._2.cnt.raw,
        0x0400_010C => bus.tim._3.counter(),
        0x0400_010E => bus.tim._3.cnt.raw,

        // Serial Communication 1
        0x0400_0128 => unimplementedRead("Read halfword from SIOCNT", .{}),

        // Keypad Input
        0x0400_0130 => bus.io.keyinput.raw,

        // Interrupts
        0x0400_0200 => bus.io.ie.raw,
        0x0400_0202 => bus.io.irq.raw,
        0x0400_0204 => unimplementedRead("Read halfword from WAITCNT", .{}),
        0x0400_0208 => @boolToInt(bus.io.ime),
        else => undRead("Tried to read halfword from 0x{X:0>8}", .{addr}),
    };
}

pub fn write16(bus: *Bus, addr: u32, halfword: u16) void {
    switch (addr) {
        // Display
        0x0400_0000 => bus.ppu.dispcnt.raw = halfword,
        0x0400_0004 => bus.ppu.dispstat.raw = halfword,
        0x0400_0008 => bus.ppu.bg[0].cnt.raw = halfword,
        0x0400_000A => bus.ppu.bg[1].cnt.raw = halfword,
        0x0400_000C => bus.ppu.bg[2].cnt.raw = halfword,
        0x0400_000E => bus.ppu.bg[3].cnt.raw = halfword,
        0x0400_0010 => bus.ppu.bg[0].hofs.raw = halfword, // TODO: Don't write out every HOFS / VOFS?
        0x0400_0012 => bus.ppu.bg[0].vofs.raw = halfword,
        0x0400_0014 => bus.ppu.bg[1].hofs.raw = halfword,
        0x0400_0016 => bus.ppu.bg[1].vofs.raw = halfword,
        0x0400_0018 => bus.ppu.bg[2].hofs.raw = halfword,
        0x0400_001A => bus.ppu.bg[2].vofs.raw = halfword,
        0x0400_001C => bus.ppu.bg[3].hofs.raw = halfword,
        0x0400_001E => bus.ppu.bg[3].vofs.raw = halfword,
        0x0400_0020 => log.warn("Wrote 0x{X:0>4} to BG2PA", .{halfword}),
        0x0400_0026 => log.warn("Wrote 0x{X:0>4} to BG2PD", .{halfword}),
        0x0400_0030 => log.warn("Wrote 0x{X:0>4} to BG3PA", .{halfword}),
        0x0400_0036 => log.warn("Wrote 0x{X:0>4} to BG3PD", .{halfword}),
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

        // Sound
        0x0400_0080 => bus.apu.ch_vol_cnt.raw = halfword,
        0x0400_0082 => bus.apu.dma_cnt.raw = halfword,
        0x0400_0084 => bus.apu.setSoundCntX(halfword >> 7 & 1 == 1),
        0x0400_0088 => bus.apu.bias.raw = halfword,

        // Dma Transfers
        0x0400_00B8 => bus.dma._0.writeWordCount(halfword),
        0x0400_00BA => bus.dma._0.writeCntHigh(halfword),
        0x0400_00C4 => bus.dma._1.writeWordCount(halfword),
        0x0400_00C6 => bus.dma._1.writeCntHigh(halfword),
        0x0400_00D0 => bus.dma._2.writeWordCount(halfword),
        0x0400_00D2 => bus.dma._2.writeCntHigh(halfword),
        0x0400_00DC => bus.dma._3.writeWordCount(halfword),
        0x0400_00DE => bus.dma._3.writeCntHigh(halfword),

        // Timers
        0x0400_0100 => bus.tim._0.writeCntLow(halfword),
        0x0400_0102 => bus.tim._0.writeCntHigh(halfword),
        0x0400_0104 => bus.tim._1.writeCntLow(halfword),
        0x0400_0106 => bus.tim._1.writeCntHigh(halfword),
        0x0400_0108 => bus.tim._2.writeCntLow(halfword),
        0x0400_010A => bus.tim._2.writeCntHigh(halfword),
        0x0400_010C => bus.tim._3.writeCntLow(halfword),
        0x0400_010E => bus.tim._3.writeCntHigh(halfword),

        // Serial Communication 1
        0x0400_0120 => log.warn("Wrote 0x{X:0>4} to SIOMULTI0", .{halfword}),
        0x0400_0122 => log.warn("Wrote 0x{X:0>4} to SIOMULTI1", .{halfword}),
        0x0400_0124 => log.warn("Wrote 0x{X:0>4} to SIOMULTI2", .{halfword}),
        0x0400_0126 => log.warn("Wrote 0x{X:0>4} to SIOMULTI3", .{halfword}),
        0x0400_0128 => log.warn("Wrote 0x{X:0>4} to SIOCNT", .{halfword}),
        0x0400_012A => log.warn("Wrote 0x{X:0>4} to SIOMLT_SEND", .{halfword}),

        // Keypad Input
        0x0400_0130 => log.warn("Wrote 0x{X:0>4} to KEYINPUT. Ignored", .{halfword}),
        0x0400_0132 => log.warn("Wrote 0x{X:0>4} to KEYCNT", .{halfword}),

        // Serial Communication 2
        0x0400_0134 => log.warn("Wrote 0x{X:0>4} to RCNT", .{halfword}),
        0x0400_0140 => log.warn("Wrote 0x{X:0>4} to JOYCNT", .{halfword}),
        0x0400_0158 => log.warn("Wrote 0x{X:0>4} to JOYSTAT", .{halfword}),

        // Interrupts
        0x0400_0200 => bus.io.ie.raw = halfword,
        0x0400_0202 => bus.io.irq.raw &= ~halfword,
        0x0400_0204 => log.warn("Wrote 0x{X:0>4} to WAITCNT", .{halfword}),
        0x0400_0208 => bus.io.ime = halfword & 1 == 1,
        else => undWrite("Tried to write 0x{X:0>4} to 0x{X:0>8}", .{ halfword, addr }),
    }
}

pub fn read8(bus: *const Bus, addr: u32) u8 {
    return switch (addr) {
        // Display
        0x0400_0000 => @truncate(u8, bus.ppu.dispcnt.raw),
        0x0400_0004 => @truncate(u8, bus.ppu.dispstat.raw),
        0x0400_0006 => @truncate(u8, bus.ppu.vcount.raw),

        // Sound
        0x0400_0060 => bus.apu.ch1.sweep.raw,
        0x0400_0063 => bus.apu.ch1.envelope.raw,
        0x0400_0069 => bus.apu.ch2.envelope.raw,
        0x0400_0073 => bus.apu.ch3.vol.raw,
        0x0400_0079 => bus.apu.ch4.envelope.raw,
        0x0400_007C => bus.apu.ch4.poly.raw,
        0x0400_0081 => @truncate(u8, bus.apu.ch_vol_cnt.raw >> 8),
        0x0400_0089 => @truncate(u8, bus.apu.bias.raw >> 8),

        // Serial Communication 1
        0x0400_0128 => unimplementedRead("Read (low) byte from SIOCNT", .{}),

        // Interrupts
        0x0400_0200 => @truncate(u8, bus.io.ie.raw),
        0x0400_0300 => @enumToInt(bus.io.postflg),
        else => undRead("Tried to read byte from 0x{X:0>8}", .{addr}),
    };
}

pub fn write8(bus: *Bus, addr: u32, byte: u8) void {
    switch (addr) {
        // Display
        0x0400_0004 => bus.ppu.dispstat.raw = (bus.ppu.dispstat.raw & 0xFF00) | byte,
        0x0400_0005 => bus.ppu.dispstat.raw = (@as(u16, byte) << 8) | (bus.ppu.dispstat.raw & 0xFF),

        // Sound
        0x0400_0060 => bus.apu.ch1.sweep.raw = byte,
        0x0400_0062 => bus.apu.ch1.duty.raw = byte,
        0x0400_0063 => bus.apu.ch1.envelope.raw = byte,
        0x0400_0064 => bus.apu.ch1.setFreqLow(byte),
        0x0400_0065 => bus.apu.ch1.setFreqHigh(byte),
        0x0400_0068 => bus.apu.ch2.duty.raw = byte,
        0x0400_0069 => bus.apu.ch2.envelope.raw = byte,
        0x0400_006C => bus.apu.ch2.setFreqLow(byte),
        0x0400_006D => bus.apu.ch2.setFreqHigh(byte),
        0x0400_0070 => bus.apu.ch3.select.raw = byte,
        0x0400_0072 => bus.apu.ch3.length = byte,
        0x0400_0073 => bus.apu.ch3.vol.raw = byte,
        0x0400_0074 => bus.apu.ch3.setFreqLow(byte),
        0x0400_0075 => bus.apu.ch3.setFreqHigh(byte),
        0x0400_0078 => bus.apu.ch4.len = @truncate(u6, byte),
        0x0400_0079 => bus.apu.ch4.envelope.raw = byte,
        0x0400_007C => bus.apu.ch4.poly.raw = byte,
        0x0400_007D => bus.apu.ch4.cnt.raw = byte,
        0x0400_0080 => bus.apu.setSoundCntLLow(byte),
        0x0400_0081 => bus.apu.setSoundCntLHigh(byte),
        0x0400_0084 => bus.apu.setSoundCntX(byte >> 7 & 1 == 1),
        0x0400_0089 => bus.apu.setBiasHigh(byte),

        // Serial Communication 1
        0x0400_0128 => log.warn("Wrote 0x{X:0>2} to SIOCNT (low)", .{byte}),

        // Serial Communication 2
        0x0400_0140 => log.warn("Wrote 0x{X:0>2} to JOYCNT (low)", .{byte}),

        // Interrupts
        0x0400_0208 => bus.io.ime = byte & 1 == 1,
        0x0400_0301 => bus.io.haltcnt = if (byte >> 7 & 1 == 0) .Halt else std.debug.panic("TODO: Implement STOP", .{}),
        else => undWrite("Tried to write 0x{X:0>2} to 0x{X:0>8}", .{ byte, addr }),
    }
}

fn undRead(comptime format: []const u8, args: anytype) u8 {
    if (panic_on_und_io) std.debug.panic(format, args) else log.warn(format, args);
    return 0;
}

fn unimplementedRead(comptime format: []const u8, args: anytype) u8 {
    log.warn(format, args);
    return 0;
}

fn undWrite(comptime format: []const u8, args: anytype) void {
    if (panic_on_und_io) std.debug.panic(format, args) else log.warn(format, args);
}

/// Read / Write
pub const PostFlag = enum(u1) {
    FirstBoot = 0,
    FurtherBoots = 1,
};

/// Write Only
pub const HaltControl = enum {
    Halt,
    Stop,
    Execute,
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

/// Read / Write
pub const DmaControl = extern union {
    dad_adj: Bitfield(u16, 5, 2),
    sad_adj: Bitfield(u16, 7, 2),
    repeat: Bit(u16, 9),
    transfer_type: Bit(u16, 10),
    pak_drq: Bit(u16, 11),
    start_timing: Bitfield(u16, 12, 2),
    irq: Bit(u16, 14),
    enabled: Bit(u16, 15),
    raw: u16,
};

/// Read / Write
pub const TimerControl = extern union {
    frequency: Bitfield(u16, 0, 2),
    cascade: Bit(u16, 2),
    irq: Bit(u16, 6),
    enabled: Bit(u16, 7),
    raw: u16,
};

/// Read / Write
/// NR10
pub const Sweep = extern union {
    shift: Bitfield(u8, 0, 3),
    direction: Bit(u8, 3),
    period: Bitfield(u8, 4, 3),
    raw: u8,
};

/// Read / Write
/// This represents the Duty / Len
/// NRx1
pub const Duty = extern union {
    /// Write-only
    /// Only used when bit 6 is set
    length: Bitfield(u16, 0, 6),
    pattern: Bitfield(u16, 6, 2),
    raw: u8,
};

/// Read / Write 
/// NRx2
pub const Envelope = extern union {
    period: Bitfield(u8, 0, 3),
    direction: Bit(u8, 3),
    init_vol: Bitfield(u8, 4, 4),
    raw: u8,
};

/// Read / Write
/// NRx3, NRx4
pub const Frequency = extern union {
    /// Write-only
    frequency: Bitfield(u16, 0, 11),
    length_enable: Bit(u16, 14),
    /// Write-only
    trigger: Bit(u16, 15),

    raw: u16,
};

/// Read / Write
/// NR30
pub const WaveSelect = extern union {
    dimension: Bit(u8, 5),
    bank: Bit(u8, 6),
    enabled: Bit(u8, 7),
    raw: u8,
};

/// Read / Write
/// NR32
pub const WaveVolume = extern union {
    kind: Bitfield(u8, 5, 2),
    force: Bit(u8, 7),
    raw: u8,
};

/// Read / Write
/// NR43
pub const PolyCounter = extern union {
    div_ratio: Bitfield(u8, 0, 3),
    width: Bit(u8, 3),
    shift: Bitfield(u8, 4, 4),
    raw: u8,
};

/// Read / Write
/// NR44
pub const NoiseControl = extern union {
    length_enable: Bit(u8, 6),
    trigger: Bit(u8, 7),
    raw: u8,
};

/// Read / Write
pub const ChannelVolumeControl = extern union {
    left_vol: Bitfield(u16, 0, 3),
    right_vol: Bitfield(u16, 4, 3),

    ch1_right: Bit(u16, 8),
    ch2_right: Bit(u16, 9),
    ch3_right: Bit(u16, 10),
    ch4_right: Bit(u16, 11),
    ch1_left: Bit(u16, 12),
    ch2_left: Bit(u16, 13),
    ch3_left: Bit(u16, 14),
    ch4_left: Bit(u16, 15),
    raw: u16,
};

/// Read / Write
pub const DmaSoundControl = extern union {
    ch_vol: Bitfield(u16, 0, 2),
    sa_vol: Bit(u16, 2),
    sb_vol: Bit(u16, 3),

    sa_right_enable: Bit(u16, 8),
    sa_left_enable: Bit(u16, 9),
    sa_timer: Bit(u16, 10),
    /// Write only?
    sa_reset: Bit(u16, 11),

    sb_right_enable: Bit(u16, 12),
    sb_left_enable: Bit(u16, 13),
    sb_timer: Bit(u16, 14),
    /// Write only?
    sb_reset: Bit(u16, 15),
    raw: u16,
};

/// Read / Write
pub const SoundControl = extern union {
    /// Read-only
    ch1_enable: Bit(u8, 0),
    /// Read-only
    ch2_enable: Bit(u8, 1),
    /// Read-only
    ch3_enable: Bit(u8, 2),
    /// Read-only
    ch4_enable: Bit(u8, 3),
    apu_enable: Bit(u8, 7),
    raw: u8,
};

/// Read / Write
pub const SoundBias = extern union {
    level: Bitfield(u16, 1, 9),
    sampling_cycle: Bitfield(u16, 14, 2),
    raw: u16,
};
