const std = @import("std");

const SoundFifo = std.fifo.LinearFifo(u8, .{ .Static = 0x20 });

const io = @import("bus/io.zig");

pub const Apu = struct {
    const Self = @This();

    ch1: ToneSweep,
    ch2: Tone,
    ch3: Wave,
    ch4: Noise,
    chA: DmaSound,
    chB: DmaSound,

    bias: io.SoundBias,
    ch_vol_cnt: io.ChannelVolumeControl,
    dma_cnt: io.DmaSoundControl,
    cnt: io.SoundControl,

    pub fn init() Self {
        return .{
            .ch1 = ToneSweep.init(),
            .ch2 = Tone.init(),
            .ch3 = Wave.init(),
            .ch4 = Noise.init(),
            .chA = DmaSound.init(),
            .chB = DmaSound.init(),

            .ch_vol_cnt = .{ .raw = 0 },
            .dma_cnt = .{ .raw = 0 },
            .cnt = .{ .raw = 0 },
            .bias = .{ .raw = 0x0200 },
        };
    }

    pub fn setSoundCntX(self: *Self, value: bool) void {
        self.cnt.apu_enable.write(value);
    }

    pub fn setSoundCntLLow(self: *Self, byte: u8) void {
        self.ch_vol_cnt.raw = (self.ch_vol_cnt.raw & 0xFF00) | byte;
    }

    pub fn setSoundCntLHigh(self: *Self, byte: u8) void {
        self.ch_vol_cnt.raw = @as(u16, byte) << 8 | (self.ch_vol_cnt.raw & 0xFF);
    }

    pub fn setBiasHigh(self: *Self, byte: u8) void {
        self.bias.raw = (@as(u16, byte) << 8) | (self.bias.raw & 0xFF);
    }
};

const ToneSweep = struct {
    const Self = @This();

    /// NR10
    sweep: io.Sweep,
    /// NR11
    duty: io.Duty,
    /// NR12
    envelope: io.Envelope,
    /// NR13, NR14
    freq: io.Frequency,

    fn init() Self {
        return .{
            .sweep = .{ .raw = 0 },
            .duty = .{ .raw = 0 },
            .envelope = .{ .raw = 0 },
            .freq = .{ .raw = 0 },
        };
    }

    pub fn setFreqLow(self: *Self, byte: u8) void {
        self.freq.raw = (self.freq.raw & 0xFF00) | byte;
    }

    pub fn setFreqHigh(self: *Self, byte: u8) void {
        self.freq.raw = (@as(u16, byte) << 8) | (self.freq.raw & 0xFF);
    }
};

const Tone = struct {
    const Self = @This();

    /// NR21
    duty: io.Duty,
    /// NR22
    envelope: io.Envelope,
    /// NR23, NR24
    freq: io.Frequency,

    fn init() Self {
        return .{
            .duty = .{ .raw = 0 },
            .envelope = .{ .raw = 0 },
            .freq = .{ .raw = 0 },
        };
    }

    pub fn setFreqLow(self: *Self, byte: u8) void {
        self.freq.raw = (self.freq.raw & 0xFF00) | byte;
    }

    pub fn setFreqHigh(self: *Self, byte: u8) void {
        self.freq.raw = @as(u16, byte) << 8 | (self.freq.raw & 0xFF);
    }
};

const Wave = struct {
    const Self = @This();

    /// Write-only
    /// NR30
    select: io.WaveSelect,
    /// NR31    
    length: u8,
    /// NR32
    vol: io.WaveVolume,
    /// NR33, NR34
    freq: io.Frequency,

    fn init() Self {
        return .{
            .select = .{ .raw = 0 },
            .vol = .{ .raw = 0 },
            .freq = .{ .raw = 0 },
            .length = 0,
        };
    }

    pub fn setFreqLow(self: *Self, byte: u8) void {
        self.freq.raw = (self.freq.raw & 0xFF00) | byte;
    }

    pub fn setFreqHigh(self: *Self, byte: u8) void {
        self.freq.raw = @as(u16, byte) << 8 | (self.freq.raw & 0xFF);
    }
};

const Noise = struct {
    const Self = @This();

    /// Write-only
    /// NR41
    len: u6,
    /// NR42
    envelope: io.Envelope,
    /// NR43
    poly: io.PolyCounter,
    /// NR44
    cnt: io.NoiseControl,

    fn init() Self {
        return .{
            .len = 0,
            .envelope = .{ .raw = 0 },
            .poly = .{ .raw = 0 },
            .cnt = .{ .raw = 0 },
        };
    }
};
const DmaSound = struct {
    const Self = @This();

    a: SoundFifo,
    b: SoundFifo,

    fn init() Self {
        return .{
            .a = SoundFifo.init(),
            .b = SoundFifo.init(),
        };
    }
};
