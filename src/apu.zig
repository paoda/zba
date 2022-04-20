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
    /// NR51
    psg_cnt: io.ChannelVolumeControl,
    dma_cnt: io.DmaSoundControl,
    cnt: io.SoundControl,

    sampling_cycle: u2,
    stream: *SDL.SDL_AudioStream,
    sched: *Scheduler,

    fs: FrameSequencer,
    capacitor: f32,

    pub fn init(sched: *Scheduler) Self {
        const apu: Self = .{
            .ch1 = ToneSweep.init(sched),
            .ch2 = Tone.init(),
            .ch3 = Wave.init(),
            .ch4 = Noise.init(),
            .chA = DmaSound(.A).init(),
            .chB = DmaSound(.B).init(),

            .psg_cnt = .{ .raw = 0 },
            .dma_cnt = .{ .raw = 0 },
            .cnt = .{ .raw = 0 },
            .bias = .{ .raw = 0x0200 },

            .sampling_cycle = 0b00,
            .stream = SDL.SDL_NewAudioStream(SDL.AUDIO_F32, 2, 1 << 15, SDL.AUDIO_F32, 2, host_sample_rate) orelse unreachable,
            .sched = sched,

            .capacitor = 0,
            .fs = FrameSequencer.init(),
        };

        sched.push(.SampleAudio, sched.now() + apu.sampleTicks());
        sched.push(.{ .ApuChannel = 0 }, sched.now() + SquareWave.ticks);
        sched.push(.FrameSequencer, sched.now() + ((1 << 24) / 512));

        return apu;
    }

    fn reset(self: *Self) void {
        self.ch1.reset();
        // TODO: Reset the rest of the channels
    }

    pub fn setDmaCnt(self: *Self, value: u16) void {
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

            // TODO: Reset Duty Position for Ch2 Square
            self.ch1.square.pos = 0;

            // TODO: Reset Channel 3 offset ptr
        } else {
            self.reset();
        }
    }

    /// NR52
    pub fn soundCntX(self: *const Self) u32 {
        const apu_enable = @boolToInt(self.cnt.apu_enable.read());

        const ch1_enable = @boolToInt(self.ch1.enabled);
        const ch2_enable = @boolToInt(self.ch2.enabled);
        const ch3_enable = @boolToInt(self.ch3.enabled);
        const ch4_enable = @boolToInt(self.ch4.enabled);

        return apu_enable << 7 | ch4_enable << 3 | ch3_enable << 2 | ch2_enable << 1 | ch1_enable;
    }

    /// NR50
    pub fn setSoundCntLLow(self: *Self, byte: u8) void {
        self.psg_cnt.raw = (self.psg_cnt.raw & 0xFF00) | byte;
    }

    /// NR51
    pub fn setSoundCntLHigh(self: *Self, byte: u8) void {
        self.psg_cnt.raw = @as(u16, byte) << 8 | (self.psg_cnt.raw & 0xFF);
    }

    pub fn setBiasHigh(self: *Self, byte: u8) void {
        self.bias.raw = (@as(u16, byte) << 8) | (self.bias.raw & 0xFF);
    }

    pub fn sampleAudio(self: *Self, late: u64) void {

        // Sample Channel 1
        const ch1_sample = self.highPassFilter(self.ch1.amplitude(), self.ch1.enabled);
        const ch1_left = if (self.psg_cnt.ch1_left.read()) ch1_sample else 0;
        const ch1_right = if (self.psg_cnt.ch1_right.read()) ch1_sample else 0;

        const mixed_left = ch1_left;
        const mixed_right = ch1_right;

        // Apply NR50 Volume Modifications
        const nr50_left = (@intToFloat(f32, self.psg_cnt.left_vol.read()) + 1.0) * mixed_left;
        const nr50_right = (@intToFloat(f32, self.psg_cnt.right_vol.read()) + 1.0) * mixed_right;

        // Apply SOUNDCNT_H Volume Modifications
        const psg_left = switch (self.dma_cnt.ch_vol.read()) {
            0b00 => nr50_left * 0.25,
            0b01 => nr50_left * 0.5,
            0b10 => nr50_left * 0.75,
            0b11 => nr50_left, // Prohibited
        };

        const psg_right = switch (self.dma_cnt.ch_vol.read()) {
            0b00 => nr50_right * 0.25,
            0b01 => nr50_right * 0.5,
            0b10 => nr50_right * 0.75,
            0b11 => nr50_right, // Prohibited
        };

        // Sample Dma Channels
        // const chA = if (self.dma_cnt.chA_vol.read()) self.chA.amplitude() else self.chA.amplitude() / 2;
        // const chA_left = if (self.dma_cnt.chA_left.read()) chA else 0;
        // const chA_right = if (self.dma_cnt.chA_right.read()) chA else 0;

        // const chB = if (self.dma_cnt.chB_vol.read()) self.chB.amplitude() else self.chB.amplitude() / 2;
        // const chB_left = if (self.dma_cnt.chB_left.read()) chB else 0;
        // const chB_right = if (self.dma_cnt.chB_right.read()) chB else 0;

        // Mix all Channels
        // const left = (chA_left + chB_left + psg_left) / 3;
        // const right = (chA_right + chB_right + psg_right) / 3
        const left = psg_left;
        const right = psg_right;

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

    pub fn tickFrameSequencer(self: *Self, late: u64) void {
        self.fs.tick();

        switch (self.fs.step) {
            7 => self.tickEnvelopes(), // Clock Envelope
            0, 4 => self.tickLengths(), // Clock Length
            2, 6 => {
                // Clock Length and Sweep
                self.tickLengths();
                self.ch1.tickSweep();
            },
            1, 3, 5 => {},
        }

        self.sched.push(.FrameSequencer, self.sched.now() + ((1 << 24) / 512) - late);
    }

    fn tickLengths(self: *Self) void {
        self.ch1.tickLength();
        self.ch2.tickLength();
        self.ch3.tickLength();
        self.ch4.tickLength();
    }

    fn tickEnvelopes(self: *Self) void {
        self.ch1.tickEnvelope();
        self.ch2.tickEnvelope();
        self.ch4.tickEnvelope();
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

    fn highPassFilter(self: *Self, sample: f32, ch_enabled: bool) f32 {
        const charge_factor = 0.999958;

        var output: f32 = 0;
        if (ch_enabled) {
            output = sample - self.capacitor;
            self.capacitor = sample - output * std.math.pow(f32, charge_factor, @intToFloat(f32, (1 << 22) / self.sampleRate()));
        }

        return output;
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

    /// Length Functionality
    len_dev: Length,
    /// Sweep Functionality
    sweep_dev: Sweep,
    /// Envelope Functionality
    env_dev: Envelope,
    /// Frequency Timer Functionality
    square: SquareWave,
    enabled: bool,

    sample: u8,

    const Sweep = struct {
        const This = @This();

        timer: u8,
        enabled: bool,
        shadow: u11,

        pub fn init() This {
            return .{
                .timer = 0,
                .enabled = false,
                .shadow = 0,
            };
        }

        pub fn tick(this: *This, ch1: *Self) void {
            if (this.timer != 0) this.timer -= 1;

            if (this.timer == 0) {
                const period = ch1.sweep.period.read();
                this.timer = if (period == 0) 8 else period;

                if (this.enabled and period != 0) {
                    const new_freq = this.calcFrequency(ch1);

                    if (new_freq <= 0x7FF and ch1.sweep.shift.read() != 0) {
                        ch1.freq.frequency.write(@truncate(u11, new_freq));
                        this.shadow = @truncate(u11, new_freq);

                        _ = this.calcFrequency(ch1);
                    }
                }
            }
        }

        fn calcFrequency(this: *This, ch1: *Self) u12 {
            const shadow = @as(u12, this.shadow);
            const shadow_shifted = shadow >> ch1.sweep.shift.read();
            const decrease = ch1.sweep.direction.read();

            const freq = if (decrease) shadow - shadow_shifted else shadow + shadow_shifted;

            if (freq > 0x7FF) ch1.enabled = false;

            return freq;
        }
    };

    fn init(sched: *Scheduler) Self {
        return .{
            .sweep = .{ .raw = 0 },
            .duty = .{ .raw = 0 },
            .envelope = .{ .raw = 0 },
            .freq = .{ .raw = 0 },
            .sample = 0,
            .enabled = false,

            .square = SquareWave.init(sched),
            .len_dev = Length.init(),
            .sweep_dev = Sweep.init(),
            .env_dev = Envelope.init(),
        };
    }

    fn reset(self: *Self) void {
        self.sweep.raw = 0;
        self.duty.raw = 0;
        self.envelope.raw = 0;
        self.freq.raw = 0;

        self.sample = 0;
        self.enabled = false;
    }

    fn tickSweep(self: *Self) void {
        self.sweep_dev.tick(self);
    }

    pub fn tickLength(self: *Self) void {
        self.len_dev.tick(self.freq, &self.enabled);
    }

    pub fn tickEnvelope(self: *Self) void {
        self.env_dev.tick(self.envelope);
    }

    pub fn channelTimerOverflow(self: *Self, late: u64) void {
        self.square.handleTimerOverflow(self.freq, late);

        self.sample = 0;
        if (!self.isDacEnabled()) return;
        self.sample = if (self.enabled) self.square.sample(self.duty) * self.env_dev.vol else 0;
    }

    fn amplitude(self: *const Self) f32 {
        return (@intToFloat(f32, self.sample) / 7.5) - 1.0;
    }

    /// NR11, NR12
    pub fn setSoundCntH(self: *Self, value: u16) void {
        self.setDuty(@truncate(u8, value));
        self.setEnvelope(@truncate(u8, value >> 8));
    }

    /// NR11
    pub fn setDuty(self: *Self, value: u8) void {
        self.duty.raw = value;
        self.len_dev.timer = @as(u7, self.duty.length.read() ^ 0x3F);
    }

    /// NR12
    pub fn setEnvelope(self: *Self, value: u8) void {
        self.envelope.raw = value;
        if (!self.isDacEnabled()) self.enabled = false;
    }

    /// NR13, NR14
    pub fn setFreq(self: *Self, fs: *const FrameSequencer, value: u16) void {
        self.setFreqLow(@truncate(u8, value));
        self.setFreqHigh(fs, @truncate(u8, value >> 8));
    }

    /// NR13
    pub fn setFreqLow(self: *Self, byte: u8) void {
        self.freq.raw = (self.freq.raw & 0xFF00) | byte;
    }

    /// NR14
    pub fn setFreqHigh(self: *Self, fs: *const FrameSequencer, byte: u8) void {
        var new: io.Frequency = .{ .raw = (@as(u16, byte) << 8) | (self.freq.raw & 0xFF) };

        if (new.trigger.read()) {
            self.enabled = true; // FIXME: is this necessary?

            if (self.len_dev.timer == 0) {
                self.len_dev.timer = 64;

                // We unset this on the old frequency because of the obscure
                // behaviour outside of this if statement's scope
                self.freq.length_enable.write(false);
            }

            // TODO: Reload Frequency Timer
            self.square.reloadTimer(self.freq.frequency.read());

            // Reload Envelope period and timer
            self.env_dev.timer = self.envelope.period.read();
            self.env_dev.vol = self.envelope.init_vol.read();

            // Sweep Trigger Behaviour
            const sw_period = self.sweep.period.read();
            const sw_shift = self.sweep.shift.read();

            self.sweep_dev.shadow = self.freq.frequency.read();
            self.sweep_dev.timer = if (sw_period == 0) 8 else sw_period;
            self.sweep_dev.enabled = sw_period != 0 or sw_shift != 0;
            if (sw_shift != 0) _ = self.sweep_dev.calcFrequency(self);

            self.enabled = self.isDacEnabled();
        }

        self.square.updateLength(fs, self, new);
        self.freq = new;
    }

    fn isDacEnabled(self: *const Self) bool {
        return self.envelope.raw & 0xF8 != 0;
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

    /// Length Functionarlity
    len_dev: Length,

    /// Envelope Functionality
    env_dev: Envelope,

    enabled: bool,

    fn init() Self {
        return .{
            .duty = .{ .raw = 0 },
            .envelope = .{ .raw = 0 },
            .freq = .{ .raw = 0 },
            .enabled = false,

            .len_dev = Length.init(),
            .env_dev = Envelope.init(),
        };
    }

    pub fn tickLength(self: *Self) void {
        self.len_dev.tick(self.freq, &self.enabled);
    }

    pub fn tickEnvelope(self: *Self) void {
        self.env_dev.tick(self.envelope);
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

    /// Length Functionarlity
    len_dev: Length,

    enabled: bool,

    fn init() Self {
        return .{
            .select = .{ .raw = 0 },
            .vol = .{ .raw = 0 },
            .freq = .{ .raw = 0 },
            .length = 0,

            .len_dev = Length.init(),
            .enabled = false,
        };
    }

    pub fn tickLength(self: *Self) void {
        self.len_dev.tick(self.freq, &self.enabled);
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

    /// Length Functionarlity
    len_dev: Length,

    /// Envelope Functionality
    env_dev: Envelope,

    enabled: bool,

    fn init() Self {
        return .{
            .len = 0,
            .envelope = .{ .raw = 0 },
            .poly = .{ .raw = 0 },
            .cnt = .{ .raw = 0 },
            .enabled = false,

            .len_dev = Length.init(),
            .env_dev = Envelope.init(),
        };
    }

    pub fn tickLength(self: *Self) void {
        self.len_dev.ch4Tick(self.cnt, &self.enabled);
    }

    pub fn tickEnvelope(self: *Self) void {
        self.env_dev.tick(self.envelope);
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

const FrameSequencer = struct {
    const Self = @This();

    step: u3,

    pub fn init() Self {
        return .{ .step = 0 };
    }

    pub fn tick(self: *Self) void {
        self.step +%= 1;
    }

    fn lengthIsNext(self: *const Self) bool {
        return (self.step +% 1) & 1 == 0; // Steps, 0, 2, 4, and 6 clock length
    }
};

const Length = struct {
    const Self = @This();

    timer: u7,

    pub fn init() Self {
        return .{ .timer = 0 };
    }

    fn tick(self: *Self, freq: io.Frequency, ch_enabled: *bool) void {
        const len_enable = freq.length_enable.read();

        if (len_enable and self.timer > 0) {
            self.timer -= 1;

            // if length timer is now 0
            if (self.timer == 0) ch_enabled.* = false;
        }
    }

    fn ch4Tick(self: *Self, cnt: io.NoiseControl, ch_enabled: *bool) void {
        const len_enable = cnt.length_enable.read();

        if (len_enable and self.timer > 0) {
            self.timer -= 1;

            // if length timer is now 0
            if (self.timer == 0) ch_enabled.* = false;
        }
    }
};

const Envelope = struct {
    const Self = @This();

    /// Period Timer
    timer: u3,
    /// Current Volume
    vol: u4,

    pub fn init() Self {
        return .{ .timer = 0, .vol = 0 };
    }

    pub fn tick(self: *Self, cnt: io.Envelope) void {
        if (cnt.period.read() != 0) {
            if (self.timer != 0) self.timer -= 1;

            if (self.timer == 0) {
                self.timer = cnt.period.read();

                if (cnt.direction.read()) {
                    if (self.vol < 0xF) self.vol += 1;
                } else {
                    if (self.vol > 0x0) self.vol -= 1;
                }
            }
        }
    }
};

const SquareWave = struct {
    const Self = @This();
    const ticks: u64 = (1 << 24) / (1 << 22);

    pos: u3,
    sched: *Scheduler,
    timer: u12,

    pub fn init(sched: *Scheduler) Self {
        return .{
            .timer = 0,
            .pos = 0,
            .sched = sched,
        };
    }

    /// Obscure NRx4 Behaviour
    fn updateLength(_: *Self, fs: *const FrameSequencer, ch1: *ToneSweep, new_cnt: io.Frequency) void {
        if (!fs.lengthIsNext() and !ch1.freq.length_enable.read() and new_cnt.length_enable.read() and ch1.len_dev.timer != 0) {
            ch1.len_dev.timer -= 1;

            if (ch1.len_dev.timer == 0 and !new_cnt.trigger.read()) ch1.enabled = false;
        }
    }

    fn handleTimerOverflow(self: *Self, cnt: io.Frequency, late: u64) void {
        const timer = (2048 - @as(u64, cnt.frequency.read())) * 4;

        self.timer = @truncate(u12, timer);
        self.pos = (self.pos +% 1) & 7;

        self.sched.push(.{ .ApuChannel = 0 }, self.sched.now() + timer * ticks - late);
    }

    fn reloadTimer(self: *Self, value: u11) void {
        self.sched.removeScheduledEvent(.{ .ApuChannel = 0 });

        const tmp: u64 = (2048 - @as(u64, value)) * 4; // What Freq Timer should be assuming no weird behaviour
        const timer = (tmp & ~@as(u64, 0x3)) | self.timer & 0x3; // Keep the last two bits from the old timer
        self.timer = @truncate(u12, timer);

        self.sched.push(.{ .ApuChannel = 0 }, self.sched.now() + timer * ticks);
    }

    fn sample(self: *const Self, cnt: io.Duty) u1 {
        const pattern = cnt.pattern.read();

        const i = self.pos ^ 7; // index of 0 should get highest bit
        const result = switch (pattern) {
            0b00 => @as(u8, 0b00000001) >> i, // 12.5%
            0b01 => @as(u8, 0b00000011) >> i, // 25%
            0b10 => @as(u8, 0b00001111) >> i, // 50%
            0b11 => @as(u8, 0b11111100) >> i, // 75%
        };

        return @truncate(u1, result);
    }
};
