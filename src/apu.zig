const std = @import("std");
const SDL = @import("sdl2");
const io = @import("bus/io.zig");

const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Scheduler = @import("scheduler.zig").Scheduler;

const SoundFifo = std.fifo.LinearFifo(u8, .{ .Static = 0x20 });
const AudioDeviceId = SDL.SDL_AudioDeviceID;

const intToBytes = @import("util.zig").intToBytes;
const log = std.log.scoped(.APU);

pub const host_sample_rate = 1 << 15;

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

    sampling_cycle: u2,
    stream: *SDL.SDL_AudioStream,
    sched: *Scheduler,

    pub fn init(sched: *Scheduler) Self {
        const apu: Self = .{
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

            .sampling_cycle = 0b00,
            .stream = SDL.SDL_NewAudioStream(SDL.AUDIO_F32, 2, 1 << 15, SDL.AUDIO_F32, 2, host_sample_rate) orelse unreachable,
            .sched = sched,
        };

        sched.push(.SampleAudio, sched.now() + apu.sampleTicks());

        return apu;
    }

    pub fn setDmaCnt(self: *Self, value: u16) void {
        const new: io.DmaSoundControl = .{ .raw = value };

        // Reinitializing instead of resetting is fine because
        // the FIFOs I'm using are stack allocated and 0x20 bytes big
        if (new.chA_reset.read()) self.chA.fifo = SoundFifo.init();
        if (new.chB_reset.read()) self.chB.fifo = SoundFifo.init();

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

    pub fn sampleAudio(self: *Self, late: u64) void {
        const chA = if (self.dma_cnt.chA_vol.read()) self.chA.amplitude() else self.chA.amplitude() / 2;
        const chA_left = if (self.dma_cnt.chA_left.read()) chA else 0;
        const chA_right = if (self.dma_cnt.chA_right.read()) chA else 0;

        const chB = if (self.dma_cnt.chB_vol.read()) self.chB.amplitude() else self.chB.amplitude() / 2;
        const chB_left = if (self.dma_cnt.chB_left.read()) chB else 0;
        const chB_right = if (self.dma_cnt.chB_right.read()) chB else 0;

        const left = (chA_left + chB_left) / 2;
        const right = (chA_right + chB_right) / 2;

        if (self.sampling_cycle != self.bias.sampling_cycle.read()) {
            log.warn("Sampling Cycle changed from {} to {}", .{ self.sampling_cycle, self.bias.sampling_cycle.read() });

            // Sample Rate Changed, Create a new Resampler since i can't figure out how to change
            // the parameters of the old one
            const old = self.stream;
            defer SDL.SDL_FreeAudioStream(old);

            self.sampling_cycle = self.bias.sampling_cycle.read();
            self.stream = SDL.SDL_NewAudioStream(SDL.AUDIO_F32, 2, @intCast(c_int, self.sampleRate()), SDL.AUDIO_F32, 2, host_sample_rate) orelse unreachable;
        }

        while (SDL.SDL_AudioStreamAvailable(self.stream) > (@sizeOf(f32) * 2 * 0x800)) {}

        _ = SDL.SDL_AudioStreamPut(self.stream, &[2]f32{ left, right }, 2 * @sizeOf(f32));
        self.sched.push(.SampleAudio, self.sched.now() + self.sampleTicks() - late);
    }

    inline fn sampleTicks(self: *const Self) u64 {
        return (1 << 24) / self.sampleRate();
    }

    inline fn sampleRate(self: *const Self) u64 {
        return @as(u64, 1) << (15 + @as(u6, self.bias.sampling_cycle.read()));
    }

    pub fn handleTimerOverflow(self: *Self, cpu: *Arm7tdmi, tim_id: u3) void {
        if (!self.cnt.apu_enable.read()) return;

        if (@boolToInt(self.dma_cnt.chA_timer.read()) == tim_id) {
            self.chA.updateSample();
            if (self.chA.len() <= 15) cpu.bus.dma._1.enableSoundDma(0x0400_00A0);
        }

        if (@boolToInt(self.dma_cnt.chB_timer.read()) == tim_id) {
            self.chB.updateSample();
            if (self.chB.len() <= 15) cpu.bus.dma._2.enableSoundDma(0x0400_00A4);
        }
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
        sample: i8,

        fn init() Self {
            return .{
                .fifo = SoundFifo.init(),
                .kind = kind,
                .sample = 0,
            };
        }

        pub fn push(self: *Self, value: u32) void {
            self.fifo.write(&intToBytes(u32, value)) catch {};
        }

        pub fn len(self: *const Self) usize {
            return self.fifo.readableLength();
        }

        pub fn updateSample(self: *Self) void {
            if (self.fifo.readItem()) |sample| self.sample = @bitCast(i8, sample);
        }

        pub fn amplitude(self: *const Self) f32 {
            return @intToFloat(f32, self.sample) / 127.5 - (1 / 255);
        }
    };
}

const DmaSoundKind = enum {
    A,
    B,
};
