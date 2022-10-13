const std = @import("std");
const SDL = @import("sdl2");
const io = @import("bus/io.zig");
const util = @import("../util.zig");

const AudioDeviceId = SDL.SDL_AudioDeviceID;

const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Scheduler = @import("scheduler.zig").Scheduler;
const ToneSweep = @import("apu/ToneSweep.zig");
const Tone = @import("apu/Tone.zig");
const Wave = @import("apu/Wave.zig");
const Noise = @import("apu/Noise.zig");

const SoundFifo = std.fifo.LinearFifo(u8, .{ .Static = 0x20 });

const intToBytes = @import("../util.zig").intToBytes;
const setHi = @import("../util.zig").setHi;
const setLo = @import("../util.zig").setLo;

const log = std.log.scoped(.APU);

pub const host_sample_rate = 1 << 15;

pub fn read(comptime T: type, apu: *const Apu, addr: u32) ?T {
    const byte = @truncate(u8, addr);

    return switch (T) {
        u16 => switch (byte) {
            0x60 => apu.ch1.sound1CntL(),
            0x62 => apu.ch1.sound1CntH(),
            0x64 => apu.ch1.sound1CntX(),
            0x68 => apu.ch2.sound2CntL(),
            0x6C => apu.ch2.sound2CntH(),

            0x70 => apu.ch3.select.raw & 0xE0, // SOUND3CNT_L
            0x72 => apu.ch3.sound3CntH(),
            0x74 => apu.ch3.freq.raw & 0x4000, // SOUND3CNT_X

            0x78 => apu.ch4.sound4CntL(),
            0x7C => apu.ch4.sound4CntH(),

            0x80 => apu.psg_cnt.raw & 0xFF77, // SOUNDCNT_L
            0x82 => apu.dma_cnt.raw & 0x770F, // SOUNDCNT_H
            0x84 => apu.soundCntX(),
            0x88 => apu.bias.raw, // SOUNDBIAS
            0x90...0x9F => apu.ch3.wave_dev.read(T, apu.ch3.select, addr),
            else => util.io.read.undef(T, log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        },
        u8 => switch (byte) {
            0x60 => apu.ch1.sound1CntL(), // NR10
            0x62 => apu.ch1.duty.raw, // NR11
            0x63 => apu.ch1.envelope.raw, // NR12
            0x68 => apu.ch2.duty.raw, // NR21
            0x69 => apu.ch2.envelope.raw, // NR22
            0x73 => apu.ch3.vol.raw, // NR32
            0x79 => apu.ch4.envelope.raw, // NR42
            0x7C => apu.ch4.poly.raw, // NR43
            0x81 => @truncate(u8, apu.psg_cnt.raw >> 8), // NR51
            0x84 => apu.soundCntX(),
            0x89 => @truncate(u8, apu.bias.raw >> 8), // SOUNDBIAS_H
            else => util.io.read.undef(T, log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        },
        u32 => util.io.read.undef(T, log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        else => @compileError("APU: Unsupported read width"),
    };
}

pub fn write(comptime T: type, apu: *Apu, addr: u32, value: T) void {
    const byte = @truncate(u8, addr);

    switch (T) {
        u32 => switch (byte) {
            0x60 => apu.ch1.setSound1Cnt(value),
            0x64 => apu.ch1.setSound1CntX(&apu.fs, @truncate(u16, value)),
            0x68 => apu.ch2.setSound2CntL(@truncate(u16, value)),
            0x6C => apu.ch2.setSound2CntH(&apu.fs, @truncate(u16, value)),
            0x70 => apu.ch3.setSound3Cnt(value),
            0x74 => apu.ch3.setSound3CntX(&apu.fs, @truncate(u16, value)),
            0x78 => apu.ch4.setSound4CntL(@truncate(u16, value)),
            0x7C => apu.ch4.setSound4CntH(&apu.fs, @truncate(u16, value)),

            0x80 => apu.setSoundCnt(value),
            // WAVE_RAM
            0x90...0x9F => apu.ch3.wave_dev.write(T, apu.ch3.select, addr, value),
            0xA0 => apu.chA.push(value), // FIFO_A
            0xA4 => apu.chB.push(value), // FIFO_B
            else => util.io.write.undef(log, "Tried to write 0x{X:0>8}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u16 => switch (byte) {
            0x60 => apu.ch1.setSound1CntL(@truncate(u8, value)), // SOUND1CNT_L
            0x62 => apu.ch1.setSound1CntH(value),
            0x64 => apu.ch1.setSound1CntX(&apu.fs, value),

            0x68 => apu.ch2.setSound2CntL(value),
            0x6C => apu.ch2.setSound2CntH(&apu.fs, value),

            0x70 => apu.ch3.setSound3CntL(@truncate(u8, value)),
            0x72 => apu.ch3.setSound3CntH(value),
            0x74 => apu.ch3.setSound3CntX(&apu.fs, value),

            0x78 => apu.ch4.setSound4CntL(value),
            0x7C => apu.ch4.setSound4CntH(&apu.fs, value),

            0x80 => apu.psg_cnt.raw = value, // SOUNDCNT_L
            0x82 => apu.setSoundCntH(value),
            0x84 => apu.setSoundCntX(value >> 7 & 1 == 1),
            0x88 => apu.bias.raw = value, // SOUNDBIAS
            // WAVE_RAM
            0x90...0x9F => apu.ch3.wave_dev.write(T, apu.ch3.select, addr, value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>4}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u8 => switch (byte) {
            0x60 => apu.ch1.setSound1CntL(value),
            0x62 => apu.ch1.setNr11(value),
            0x63 => apu.ch1.setNr12(value),
            0x64 => apu.ch1.setNr13(value),
            0x65 => apu.ch1.setNr14(&apu.fs, value),

            0x68 => apu.ch2.setNr21(value),
            0x69 => apu.ch2.setNr22(value),
            0x6C => apu.ch2.setNr23(value),
            0x6D => apu.ch2.setNr24(&apu.fs, value),

            0x70 => apu.ch3.setSound3CntL(value), // NR30
            0x72 => apu.ch3.setNr31(value),
            0x73 => apu.ch3.vol.raw = value, // NR32
            0x74 => apu.ch3.setNr33(value),
            0x75 => apu.ch3.setNr34(&apu.fs, value),

            0x78 => apu.ch4.setNr41(value),
            0x79 => apu.ch4.setNr42(value),
            0x7C => apu.ch4.poly.raw = value, // NR 43
            0x7D => apu.ch4.setNr44(&apu.fs, value),

            0x80 => apu.setNr50(value),
            0x81 => apu.setNr51(value),
            0x82 => apu.setSoundCntH(setLo(u16, apu.dma_cnt.raw, value)),
            0x83 => apu.setSoundCntH(setHi(u16, apu.dma_cnt.raw, value)),
            0x84 => apu.setSoundCntX(value >> 7 & 1 == 1), // NR52
            0x89 => apu.setSoundBiasH(value),
            0x90...0x9F => apu.ch3.wave_dev.write(T, apu.ch3.select, addr, value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>2}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        else => @compileError("APU: Unsupported write width"),
    }
}

pub const Apu = struct {
    const Self = @This();

    ch1: ToneSweep,
    ch2: Tone,
    ch3: Wave,
    ch4: Noise,
    chA: DmaSound(.A),
    chB: DmaSound(.B),

    bias: io.SoundBias,
    /// NR50, NR51
    psg_cnt: io.ChannelVolumeControl,
    dma_cnt: io.DmaSoundControl,
    cnt: io.SoundControl,

    sampling_cycle: u2,

    stream: *SDL.SDL_AudioStream,
    sched: *Scheduler,

    fs: FrameSequencer,
    capacitor: f32,

    is_buffer_full: bool,

    pub const Tick = enum { Length, Envelope, Sweep };

    pub fn init(sched: *Scheduler) Self {
        const apu: Self = .{
            .ch1 = ToneSweep.init(sched),
            .ch2 = Tone.init(sched),
            .ch3 = Wave.init(sched),
            .ch4 = Noise.init(sched),
            .chA = DmaSound(.A).init(),
            .chB = DmaSound(.B).init(),

            .psg_cnt = .{ .raw = 0 },
            .dma_cnt = .{ .raw = 0 },
            .cnt = .{ .raw = 0 },
            .bias = .{ .raw = 0x0200 },

            .sampling_cycle = 0b00,
            .stream = SDL.SDL_NewAudioStream(SDL.AUDIO_U16, 2, 1 << 15, SDL.AUDIO_U16, 2, host_sample_rate).?,
            .sched = sched,

            .capacitor = 0,
            .fs = FrameSequencer.init(),
            .is_buffer_full = false,
        };

        sched.push(.SampleAudio, apu.interval());
        sched.push(.{ .ApuChannel = 0 }, @import("apu/signal/Square.zig").interval);
        sched.push(.{ .ApuChannel = 1 }, @import("apu/signal/Square.zig").interval);
        sched.push(.{ .ApuChannel = 2 }, @import("apu/signal/Wave.zig").interval);
        sched.push(.{ .ApuChannel = 3 }, @import("apu/signal/Lfsr.zig").interval);
        sched.push(.FrameSequencer, FrameSequencer.interval);

        return apu;
    }

    fn reset(self: *Self) void {
        self.ch1.reset();
        self.ch2.reset();
        self.ch3.reset();
        self.ch4.reset();
    }

    /// SOUNDCNT
    fn setSoundCnt(self: *Self, value: u32) void {
        self.psg_cnt.raw = @truncate(u16, value);
        self.setSoundCntH(@truncate(u16, value >> 16));
    }

    /// SOUNDCNT_H
    pub fn setSoundCntH(self: *Self, value: u16) void {
        const new: io.DmaSoundControl = .{ .raw = value };

        // Reinitializing instead of resetting is fine because
        // the FIFOs I'm using are stack allocated and 0x20 bytes big
        if (new.chA_reset.read()) self.chA.fifo = SoundFifo.init();
        if (new.chB_reset.read()) self.chB.fifo = SoundFifo.init();

        self.dma_cnt = new;
    }

    /// NR52
    pub fn setSoundCntX(self: *Self, value: bool) void {
        self.cnt.apu_enable.write(value);

        if (value) {
            self.fs.step = 0; // Reset Frame Sequencer

            // Reset Square Wave Offsets
            self.ch1.square.pos = 0;
            self.ch2.square.pos = 0;

            // Reset Wave Device Offsets
            self.ch3.wave_dev.offset = 0;
        } else {
            self.reset();
        }
    }

    /// NR52
    pub fn soundCntX(self: *const Self) u8 {
        const apu_enable: u8 = @boolToInt(self.cnt.apu_enable.read());

        const ch1_enable: u8 = @boolToInt(self.ch1.enabled);
        const ch2_enable: u8 = @boolToInt(self.ch2.enabled);
        const ch3_enable: u8 = @boolToInt(self.ch3.enabled);
        const ch4_enable: u8 = @boolToInt(self.ch4.enabled);

        return apu_enable << 7 | ch4_enable << 3 | ch3_enable << 2 | ch2_enable << 1 | ch1_enable;
    }

    /// NR50
    pub fn setNr50(self: *Self, byte: u8) void {
        self.psg_cnt.raw = (self.psg_cnt.raw & 0xFF00) | byte;
    }

    /// NR51
    pub fn setNr51(self: *Self, byte: u8) void {
        self.psg_cnt.raw = @as(u16, byte) << 8 | (self.psg_cnt.raw & 0xFF);
    }

    pub fn setSoundBiasH(self: *Self, byte: u8) void {
        self.bias.raw = (@as(u16, byte) << 8) | (self.bias.raw & 0xFF);
    }

    pub fn sampleAudio(self: *Self, late: u64) void {
        self.sched.push(.SampleAudio, self.interval() -| late);

        // Whether the APU is busy or not is determined  by the main loop in emu.zig
        // This should only ever be true (because this side of the emu is single threaded)
        // When audio sync is disaabled
        if (self.is_buffer_full) return;

        var left: i16 = 0;
        var right: i16 = 0;

        // SOUNDCNT_L Channel Enable flags
        const ch_left: u4 = self.psg_cnt.ch_left.read();
        const ch_right: u4 = self.psg_cnt.ch_right.read();

        // Determine SOUNDCNT_H volume modifications
        const gba_vol: u4 = switch (self.dma_cnt.ch_vol.read()) {
            0b00 => 2,
            0b01 => 1,
            else => 0,
        };

        // Add all PSG channels together
        left += if (ch_left & 1 == 1) @as(i16, self.ch1.sample) else 0;
        left += if (ch_left >> 1 & 1 == 1) @as(i16, self.ch2.sample) else 0;
        left += if (ch_left >> 2 & 1 == 1) @as(i16, self.ch3.sample) else 0;
        left += if (ch_left >> 3 == 1) @as(i16, self.ch4.sample) else 0;

        right += if (ch_right & 1 == 1) @as(i16, self.ch1.sample) else 0;
        right += if (ch_right >> 1 & 1 == 1) @as(i16, self.ch2.sample) else 0;
        right += if (ch_right >> 2 & 1 == 1) @as(i16, self.ch3.sample) else 0;
        right += if (ch_right >> 3 == 1) @as(i16, self.ch4.sample) else 0;

        // Multiply by master channel volume
        left *= 1 + @as(i16, self.psg_cnt.left_vol.read());
        right *= 1 + @as(i16, self.psg_cnt.right_vol.read());

        // Apply GBA volume modifications to PSG Channels
        left >>= gba_vol;
        right >>= gba_vol;

        const chA_sample = self.chA.amplitude() << if (self.dma_cnt.chA_vol.read()) @as(u4, 2) else 1;
        const chB_sample = self.chB.amplitude() << if (self.dma_cnt.chB_vol.read()) @as(u4, 2) else 1;

        left += if (self.dma_cnt.chA_left.read()) chA_sample else 0;
        left += if (self.dma_cnt.chB_left.read()) chB_sample else 0;

        right += if (self.dma_cnt.chA_right.read()) chA_sample else 0;
        right += if (self.dma_cnt.chB_right.read()) chB_sample else 0;

        // Add SOUNDBIAS
        // FIXME: Is SOUNDBIAS 9-bit or 10-bit?
        const bias = @as(i16, self.bias.level.read()) << 1;
        left += bias;
        right += bias;

        const clamped_left = std.math.clamp(@bitCast(u16, left), std.math.minInt(u11), std.math.maxInt(u11));
        const clamped_right = std.math.clamp(@bitCast(u16, right), std.math.minInt(u11), std.math.maxInt(u11));

        // Extend to 16-bit signed audio samples
        const ext_left = (clamped_left << 5) | (clamped_left >> 6);
        const ext_right = (clamped_right << 5) | (clamped_right >> 6);

        // FIXME: This rarely happens
        if (self.sampling_cycle != self.bias.sampling_cycle.read()) self.replaceSDLResampler();

        _ = SDL.SDL_AudioStreamPut(self.stream, &[2]u16{ ext_left, ext_right }, 2 * @sizeOf(u16));
    }

    fn replaceSDLResampler(self: *Self) void {
        @setCold(true);
        const sample_rate = Self.sampleRate(self.bias.sampling_cycle.read());
        log.info("Sample Rate changed from {}Hz to {}Hz", .{ Self.sampleRate(self.sampling_cycle), sample_rate });

        // Sampling Cycle (Sample Rate) changed, Craete a new SDL Audio Resampler
        // FIXME: Replace SDL's Audio Resampler with either a custom or more reliable one
        const old_stream = self.stream;
        defer SDL.SDL_FreeAudioStream(old_stream);

        self.sampling_cycle = self.bias.sampling_cycle.read();
        self.stream = SDL.SDL_NewAudioStream(SDL.AUDIO_U16, 2, @intCast(c_int, sample_rate), SDL.AUDIO_U16, 2, host_sample_rate).?;
    }

    fn interval(self: *const Self) u64 {
        return (1 << 24) / Self.sampleRate(self.bias.sampling_cycle.read());
    }

    fn sampleRate(cycle: u2) u64 {
        return @as(u64, 1) << (15 + @as(u6, cycle));
    }

    pub fn onSequencerTick(self: *Self, late: u64) void {
        self.fs.tick();

        switch (self.fs.step) {
            7 => self.tick(.Envelope), // Clock Envelope
            0, 4 => self.tick(.Length), // Clock Length
            2, 6 => {
                // Clock Length and Sweep
                self.tick(.Length);
                self.tick(.Sweep);
            },
            1, 3, 5 => {},
        }

        self.sched.push(.FrameSequencer, ((1 << 24) / 512) -| late);
    }

    fn tick(self: *Self, comptime kind: Tick) void {
        self.ch1.tick(kind);

        switch (kind) {
            .Length => {
                self.ch2.tick(kind);
                self.ch3.tick(kind);
                self.ch4.tick(kind);
            },
            .Envelope => {
                self.ch2.tick(kind);
                self.ch4.tick(kind);
            },
            .Sweep => {}, // Already handled above (only for Ch1)
        }
    }

    pub fn onDmaAudioSampleRequest(self: *Self, cpu: *Arm7tdmi, tim_id: u3) void {
        if (!self.cnt.apu_enable.read()) return;

        if (@boolToInt(self.dma_cnt.chA_timer.read()) == tim_id) {
            self.chA.updateSample();
            if (self.chA.len() <= 15) cpu.bus.dma[1].requestAudio(0x0400_00A0);
        }

        if (@boolToInt(self.dma_cnt.chB_timer.read()) == tim_id) {
            self.chB.updateSample();
            if (self.chB.len() <= 15) cpu.bus.dma[2].requestAudio(0x0400_00A4);
        }
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
            self.fifo.write(&intToBytes(u32, value)) catch |e| log.err("{} Error: {}", .{ kind, e });
        }

        pub fn len(self: *const Self) usize {
            return self.fifo.readableLength();
        }

        pub fn updateSample(self: *Self) void {
            if (self.fifo.readItem()) |sample| self.sample = @bitCast(i8, sample);
        }

        pub fn amplitude(self: *const Self) i16 {
            return @as(i16, self.sample);
        }
    };
}

const DmaSoundKind = enum {
    A,
    B,
};

pub const FrameSequencer = struct {
    const interval = (1 << 24) / 512;
    const Self = @This();

    step: u3,

    pub fn init() Self {
        return .{ .step = 0 };
    }

    pub fn tick(self: *Self) void {
        self.step +%= 1;
    }

    pub fn isLengthNext(self: *const Self) bool {
        return (self.step +% 1) & 1 == 0; // Steps, 0, 2, 4, and 6 clock length
    }

    pub fn isEnvelopeNext(self: *const Self) bool {
        return (self.step +% 1) == 7;
    }
};
