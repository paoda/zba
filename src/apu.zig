const std = @import("std");
const SDL = @import("sdl2");
const io = @import("bus/io.zig");
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const SoundFifo = std.fifo.LinearFifo(u8, .{ .Static = 0x20 });
const AudioDeviceId = SDL.SDL_AudioDeviceID;

const intToBytes = @import("util.zig").intToBytes;
const log = std.log.scoped(.APU);

pub const Apu = struct {
    const Self = @This();

    ch1: ToneSweep,
    ch2: Tone,
    ch3: Wave,
    ch4: Noise,
    chA: DmaSound(.A),
    chB: DmaSound(.B),

    bias: io.SoundBias,
    ch_vol_cnt: io.ChannelVolumeControl,
    dma_cnt: io.DmaSoundControl,
    cnt: io.SoundControl,

    dev: ?AudioDeviceId,

    pub fn init() Self {
        return .{
            .ch1 = ToneSweep.init(),
            .ch2 = Tone.init(),
            .ch3 = Wave.init(),
            .ch4 = Noise.init(),
            .chA = DmaSound(.A).init(),
            .chB = DmaSound(.B).init(),

            .ch_vol_cnt = .{ .raw = 0 },
            .dma_cnt = .{ .raw = 0 },
            .cnt = .{ .raw = 0 },
            .bias = .{ .raw = 0x0200 },

            .dev = null,
        };
    }

    pub fn attachAudioDevice(self: *Self, dev: AudioDeviceId) void {
        self.dev = dev;
    }

    pub fn setDmaCnt(self: *Self, value: u16) void {
        const new: io.DmaSoundControl = .{ .raw = value };

        // Reinitializing instead of resetting is fine because
        // the FIFOs I'm using are stack allocated and 0x20 bytes big
        if (new.sa_reset.read()) self.chA.fifo = SoundFifo.init();
        if (new.sb_reset.read()) self.chB.fifo = SoundFifo.init();

        self.dma_cnt = new;
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

    pub fn handleTimerOverflow(self: *Self, kind: DmaSoundKind, cpu: *Arm7tdmi) void {
        if (!self.cnt.apu_enable.read()) return;

        const samples = switch (kind) {
            .A => blk: {
                break :blk self.chA.handleTimerOverflow(cpu, self.dma_cnt);
            },
            .B => blk: {
                break :blk self.chB.handleTimerOverflow(cpu, self.dma_cnt);
            },
        };

        if (self.dev) |dev| _ = SDL.SDL_QueueAudio(dev, &samples, 2);
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

pub fn DmaSound(comptime kind: DmaSoundKind) type {
    return struct {
        const Self = @This();

        fifo: SoundFifo,

        kind: DmaSoundKind,

        fn init() Self {
            return .{ .fifo = SoundFifo.init(), .kind = kind };
        }

        pub fn push(self: *Self, value: u32) void {
            self.fifo.write(&intToBytes(u32, value)) catch {};
        }

        pub fn pop(self: *Self) u8 {
            return self.fifo.readItem() orelse 0;
        }

        pub fn len(self: *const Self) usize {
            return self.fifo.readableLength();
        }

        pub fn handleTimerOverflow(self: *Self, cpu: *Arm7tdmi, cnt: io.DmaSoundControl) [2]u8 {
            const sample = self.pop();

            var left: u8 = 0;
            var right: u8 = 0;
            var fifo_addr: u32 = undefined;

            switch (kind) {
                .A => {
                    const vol = @boolToInt(!cnt.sa_vol.read()); // if unset, vol is 50%
                    if (cnt.sa_left_enable.read()) left = sample >> vol;
                    if (cnt.sa_right_enable.read()) right = sample >> vol;

                    fifo_addr = 0x0400_00A0;
                },
                .B => {
                    const vol = @boolToInt(!cnt.sb_vol.read()); // if unset, vol is 50%
                    if (cnt.sb_left_enable.read()) left = sample >> vol;
                    if (cnt.sb_right_enable.read()) right = sample >> vol;

                    fifo_addr = 0x0400_00A4;
                },
            }

            if (self.len() <= 15) {
                cpu.bus.dma._1.enableSoundDma(fifo_addr);
                cpu.bus.dma._2.enableSoundDma(fifo_addr);
            }

            return .{ left, right };
        }
    };
}

const DmaSoundKind = enum {
    A,
    B,
};
