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
    /// NR50, NR51
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
            .stream = SDL.SDL_NewAudioStream(SDL.AUDIO_U16, 2, 1 << 15, SDL.AUDIO_U16, 2, host_sample_rate) orelse unreachable,
            .sched = sched,

            .capacitor = 0,
            .fs = FrameSequencer.init(),
        };

        sched.push(.SampleAudio, apu.sampleTicks());
        sched.push(.{ .ApuChannel = 0 }, SquareWave.tickInterval); // Channel 1
        sched.push(.{ .ApuChannel = 1 }, SquareWave.tickInterval); // Channel 2
        sched.push(.{ .ApuChannel = 2 }, WaveDevice.tickInterval); // Channel 3
        sched.push(.{ .ApuChannel = 3 }, Lfsr.tickInterval); // Channel 4
        sched.push(.FrameSequencer, ((1 << 24) / 512));

        return apu;
    }

    fn reset(self: *Self) void {
        self.ch1.reset();
        self.ch2.reset();
        self.ch3.reset();
        self.ch4.reset();
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
        left += if (ch_left & 1 == 1) self.ch1.amplitude() else 0;
        left += if (ch_left >> 1 & 1 == 1) self.ch2.amplitude() else 0;
        left += if (ch_left >> 2 & 1 == 1) self.ch3.amplitude() else 0;
        left += if (ch_left >> 3 == 1) self.ch4.amplitude() else 0;

        right += if (ch_right & 1 == 1) self.ch1.amplitude() else 0;
        right += if (ch_right >> 1 & 1 == 1) self.ch2.amplitude() else 0;
        right += if (ch_right >> 2 & 1 == 1) self.ch3.amplitude() else 0;
        right += if (ch_right >> 3 == 1) self.ch4.amplitude() else 0;

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

        const tmp_left = std.math.clamp(@intCast(u16, left), std.math.minInt(u11), std.math.maxInt(u11));
        const tmp_right = std.math.clamp(@intCast(u16, right), std.math.minInt(u11), std.math.maxInt(u11));

        // Extend to 16-bit signed audio samples
        const final_left = (tmp_left << 5) | (tmp_left >> 6);
        const final_right = (tmp_right << 5) | (tmp_right >> 6);

        if (self.sampling_cycle != self.bias.sampling_cycle.read()) {
            log.info("Sampling Cycle changed from {} to {}", .{ self.sampling_cycle, self.bias.sampling_cycle.read() });

            // Sample Rate Changed, Create a new Resampler since i can't figure out how to change
            // the parameters of the old one
            const old = self.stream;
            defer SDL.SDL_FreeAudioStream(old);

            self.sampling_cycle = self.bias.sampling_cycle.read();
            self.stream = SDL.SDL_NewAudioStream(SDL.AUDIO_U16, 2, @intCast(c_int, self.sampleRate()), SDL.AUDIO_U16, 2, host_sample_rate) orelse unreachable;
        }

        // If we add 0x4040 to each sample the DC Offset is removed
        // note: found this through guess and check
        // FIXME: Pretty sure this is a dirty hack and should be fixed
        _ = SDL.SDL_AudioStreamPut(self.stream, &[2]u16{ final_left + 0x4040, final_right + 0x4040 }, 2 * @sizeOf(u16));
        self.sched.push(.SampleAudio, self.sampleTicks() -| late);
    }

    fn sampleTicks(self: *const Self) u64 {
        return (1 << 24) / self.sampleRate();
    }

    fn sampleRate(self: *const Self) u64 {
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

        self.sched.push(.FrameSequencer, ((1 << 24) / 512) -| late);
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
            if (self.chA.len() <= 15) cpu.bus.dma[1].requestSoundDma(0x0400_00A0);
        }

        if (@boolToInt(self.dma_cnt.chB_timer.read()) == tim_id) {
            self.chB.updateSample();
            if (self.chB.len() <= 15) cpu.bus.dma[2].requestSoundDma(0x0400_00A4);
        }
    }

    fn highPass(self: *Self, sample: f32, enabled: bool) f32 {
        return if (enabled) blk: {
            const out = sample - self.capacitor;
            const charge_factor =
                std.math.pow(f32, 0.999958, @intToFloat(f32, (1 << 22) / self.sampleRate()));

            self.capacitor = sample - out * charge_factor;
            break :blk out;
        } else 0.0;
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
    len_dev: LengthDevice,
    /// Sweep Functionality
    sweep_dev: SweepDevice,
    /// Envelope Functionality
    env_dev: EnvelopeDevice,
    /// Frequency Timer Functionality
    square: SquareWave,
    enabled: bool,

    sample: i8,

    const SweepDevice = struct {
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
            .len_dev = LengthDevice.init(),
            .sweep_dev = SweepDevice.init(),
            .env_dev = EnvelopeDevice.init(),
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
        self.len_dev.tick(self.freq.length_enable.read(), &self.enabled);
    }

    pub fn tickEnvelope(self: *Self) void {
        self.env_dev.tick(self.envelope);
    }

    pub fn channelTimerOverflow(self: *Self, late: u64) void {
        self.square.handleTimerOverflow(.Ch1, self.freq, late);

        self.sample = 0;
        if (!self.isDacEnabled()) return;
        self.sample = if (self.enabled) self.square.sample(self.duty) * @as(i8, self.env_dev.vol) else 0;
    }

    fn amplitude(self: *const Self) i16 {
        return @as(i16, self.sample);
    }

    /// NR11, NR12
    pub fn setSoundCntH(self: *Self, value: u16) void {
        self.setDuty(@truncate(u8, value));
        self.setEnvelope(@truncate(u8, value >> 8));
    }

    /// NR11
    pub fn setDuty(self: *Self, value: u8) void {
        self.duty.raw = value;
        self.len_dev.timer = @as(u7, 64) - @truncate(u6, value);
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
            self.enabled = true;

            if (self.len_dev.timer == 0) {
                self.len_dev.timer =
                    if (!fs.isLengthNext() and new.length_enable.read()) 63 else 64;
            }

            self.square.reloadTimer(.Ch1, self.freq.frequency.read());

            // Reload Envelope period and timer
            self.env_dev.timer = self.envelope.period.read();
            if (fs.isEnvelopeNext() and self.env_dev.timer != 0b111) self.env_dev.timer += 1;

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

        self.square.updateToneSweepLength(fs, self, new);
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
    len_dev: LengthDevice,
    /// Envelope Functionality
    env_dev: EnvelopeDevice,
    /// FrequencyTimer Functionality
    square: SquareWave,

    enabled: bool,
    sample: i8,

    fn init(sched: *Scheduler) Self {
        return .{
            .duty = .{ .raw = 0 },
            .envelope = .{ .raw = 0 },
            .freq = .{ .raw = 0 },
            .enabled = false,

            .square = SquareWave.init(sched),
            .len_dev = LengthDevice.init(),
            .env_dev = EnvelopeDevice.init(),

            .sample = 0,
        };
    }

    fn reset(self: *Self) void {
        self.duty.raw = 0;
        self.envelope.raw = 0;
        self.freq.raw = 0;

        self.sample = 0;
        self.enabled = false;
    }

    pub fn tickLength(self: *Self) void {
        self.len_dev.tick(self.freq.length_enable.read(), &self.enabled);
    }

    pub fn tickEnvelope(self: *Self) void {
        self.env_dev.tick(self.envelope);
    }

    pub fn channelTimerOverflow(self: *Self, late: u64) void {
        self.square.handleTimerOverflow(.Ch2, self.freq, late);

        self.sample = 0;
        if (!self.isDacEnabled()) return;
        self.sample = if (self.enabled) self.square.sample(self.duty) * @as(i8, self.env_dev.vol) else 0;
    }

    fn amplitude(self: *const Self) i16 {
        return @as(i16, self.sample);
    }

    /// NR21, NR22
    pub fn setSoundCntH(self: *Self, value: u16) void {
        self.setDuty(@truncate(u8, value));
        self.setEnvelope(@truncate(u8, value >> 8));
    }

    /// NR21
    pub fn setDuty(self: *Self, value: u8) void {
        self.duty.raw = value;
        self.len_dev.timer = @as(u7, 64) - @truncate(u6, value);
    }

    /// NR22
    pub fn setEnvelope(self: *Self, value: u8) void {
        self.envelope.raw = value;
        if (!self.isDacEnabled()) self.enabled = false;
    }

    /// NR23, NR24
    pub fn setFreq(self: *Self, fs: *const FrameSequencer, value: u16) void {
        self.setFreqLow(@truncate(u8, value));
        self.setFreqHigh(fs, @truncate(u8, value >> 8));
    }

    /// NR23
    pub fn setFreqLow(self: *Self, byte: u8) void {
        self.freq.raw = (self.freq.raw & 0xFF00) | byte;
    }

    /// NR24
    pub fn setFreqHigh(self: *Self, fs: *const FrameSequencer, byte: u8) void {
        var new: io.Frequency = .{ .raw = (@as(u16, byte) << 8) | (self.freq.raw & 0xFF) };

        if (new.trigger.read()) {
            self.enabled = true;

            if (self.len_dev.timer == 0) {
                self.len_dev.timer =
                    if (!fs.isLengthNext() and new.length_enable.read()) 63 else 64;
            }

            self.square.reloadTimer(.Ch2, self.freq.frequency.read());

            // Reload Envelope period and timer
            self.env_dev.timer = self.envelope.period.read();
            if (fs.isEnvelopeNext() and self.env_dev.timer != 0b111) self.env_dev.timer += 1;

            self.env_dev.vol = self.envelope.init_vol.read();

            self.enabled = self.isDacEnabled();
        }

        self.square.updateToneLength(fs, self, new);
        self.freq = new;
    }

    fn isDacEnabled(self: *const Self) bool {
        return self.envelope.raw & 0xF8 != 0;
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
    len_dev: LengthDevice,
    wave_dev: WaveDevice,

    enabled: bool,
    sample: i8,

    fn init(sched: *Scheduler) Self {
        return .{
            .select = .{ .raw = 0 },
            .vol = .{ .raw = 0 },
            .freq = .{ .raw = 0 },
            .length = 0,

            .len_dev = LengthDevice.init(),
            .wave_dev = WaveDevice.init(sched),
            .enabled = false,
            .sample = 0,
        };
    }

    fn reset(self: *Self) void {
        self.select.raw = 0;
        self.length = 0;
        self.vol.raw = 0;
        self.freq.raw = 0;

        self.sample = 0;
        self.enabled = false;
    }

    pub fn tickLength(self: *Self) void {
        self.len_dev.tick(self.freq.length_enable.read(), &self.enabled);
    }

    /// NR30
    pub fn setWaveSelect(self: *Self, value: u8) void {
        self.select.raw = value;
        if (!self.select.enabled.read()) self.enabled = false;
    }

    /// NR31, NR32
    pub fn setSoundCntH(self: *Self, value: u16) void {
        self.setLength(@truncate(u8, value));
        self.vol.raw = (@truncate(u8, value >> 8));
    }

    /// NR31
    pub fn setLength(self: *Self, len: u8) void {
        self.length = len;
        self.len_dev.timer = 256 - @as(u9, len);
    }

    /// NR33, NR34
    pub fn setFreq(self: *Self, fs: *const FrameSequencer, value: u16) void {
        self.setFreqLow(@truncate(u8, value));
        self.setFreqHigh(fs, @truncate(u8, value >> 8));
    }

    /// NR33
    pub fn setFreqLow(self: *Self, byte: u8) void {
        self.freq.raw = (self.freq.raw & 0xFF00) | byte;
    }

    /// NR34
    pub fn setFreqHigh(self: *Self, fs: *const FrameSequencer, byte: u8) void {
        var new: io.Frequency = .{ .raw = (@as(u16, byte) << 8) | (self.freq.raw & 0xFF) };

        if (new.trigger.read()) {
            self.enabled = true;

            if (self.len_dev.timer == 0) {
                self.len_dev.timer =
                    if (!fs.isLengthNext() and new.length_enable.read()) 255 else 256;
            }

            // Update The Frequency Timer
            self.wave_dev.reloadTimer(self.freq.frequency.read());
            self.wave_dev.offset = 0;

            self.enabled = self.select.enabled.read();
        }

        self.wave_dev.updateLength(fs, self, new);
        self.freq = new;
    }

    pub fn channelTimerOverflow(self: *Self, late: u64) void {
        self.wave_dev.handleTimerOverflow(self.freq, self.select, late);

        self.sample = 0;
        if (!self.select.enabled.read()) return;
        // Convert unsigned 4-bit wave sample to signed 8-bit sample
        self.sample = (2 * @as(i8, self.wave_dev.sample(self.select)) - 15) >> self.wave_dev.shift(self.vol);
    }

    fn amplitude(self: *const Self) i16 {
        return @as(i16, self.sample);
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
    len_dev: LengthDevice,

    /// Envelope Functionality
    env_dev: EnvelopeDevice,

    // Linear Feedback Shift Register
    lfsr: Lfsr,

    enabled: bool,
    sample: i8,

    fn init(sched: *Scheduler) Self {
        return .{
            .len = 0,
            .envelope = .{ .raw = 0 },
            .poly = .{ .raw = 0 },
            .cnt = .{ .raw = 0 },
            .enabled = false,

            .len_dev = LengthDevice.init(),
            .env_dev = EnvelopeDevice.init(),
            .lfsr = Lfsr.init(sched),

            .sample = 0,
        };
    }

    fn reset(self: *Self) void {
        self.len = 0;
        self.envelope.raw = 0;
        self.poly.raw = 0;
        self.cnt.raw = 0;

        self.sample = 0;
        self.enabled = false;
    }

    pub fn tickLength(self: *Self) void {
        self.len_dev.tick(self.cnt.length_enable.read(), &self.enabled);
    }

    pub fn tickEnvelope(self: *Self) void {
        self.env_dev.tick(self.envelope);
    }

    /// NR41
    pub fn setLength(self: *Self, len: u8) void {
        self.len = @truncate(u6, len);
        self.len_dev.timer = @as(u7, 64) - @truncate(u6, len);
    }

    /// NR42
    pub fn setEnvelope(self: *Self, value: u8) void {
        self.envelope.raw = value;
        if (!self.isDacEnabled()) self.enabled = false;
    }

    /// NR41, NR42
    pub fn setSoundCntL(self: *Self, value: u16) void {
        self.setLength(@truncate(u8, value));
        self.setEnvelope(@truncate(u8, value >> 8));
    }

    /// NR43, NR44
    pub fn setSoundCntH(self: *Self, fs: *const FrameSequencer, value: u16) void {
        self.poly.raw = @truncate(u8, value);
        self.setCnt(fs, @truncate(u8, value >> 8));
    }

    /// NR44
    pub fn setCnt(self: *Self, fs: *const FrameSequencer, byte: u8) void {
        var new: io.NoiseControl = .{ .raw = byte };

        if (new.trigger.read()) {
            self.enabled = true;

            if (self.len_dev.timer == 0) {
                self.len_dev.timer =
                    if (!fs.isLengthNext() and new.length_enable.read()) 63 else 64;
            }

            // Update The Frequency Timer
            self.lfsr.reloadTimer(self.poly);
            self.lfsr.shift = 0x7FFF;

            // Update Envelope and Volume
            self.env_dev.timer = self.envelope.period.read();
            if (fs.isEnvelopeNext() and self.env_dev.timer != 0b111) self.env_dev.timer += 1;

            self.env_dev.vol = self.envelope.init_vol.read();

            self.enabled = self.isDacEnabled();
        }

        self.lfsr.updateLength(fs, self, new);
        self.cnt = new;
    }

    pub fn channelTimerOverflow(self: *Self, late: u64) void {
        self.lfsr.handleTimerOverflow(self.poly, late);

        self.sample = 0;
        if (!self.isDacEnabled()) return;
        self.sample = if (self.enabled) self.lfsr.sample() * @as(i8, self.env_dev.vol) else 0;
    }

    fn amplitude(self: *const Self) i16 {
        return @as(i16, self.sample);
    }

    fn isDacEnabled(self: *const Self) bool {
        return self.envelope.raw & 0xF8 != 0x00;
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

const FrameSequencer = struct {
    const Self = @This();

    step: u3,

    pub fn init() Self {
        return .{ .step = 0 };
    }

    pub fn tick(self: *Self) void {
        self.step +%= 1;
    }

    fn isLengthNext(self: *const Self) bool {
        return (self.step +% 1) & 1 == 0; // Steps, 0, 2, 4, and 6 clock length
    }

    fn isEnvelopeNext(self: *const Self) bool {
        return (self.step +% 1) == 7;
    }
};

const LengthDevice = struct {
    const Self = @This();

    timer: u9,

    pub fn init() Self {
        return .{ .timer = 0 };
    }

    fn tick(self: *Self, length_enable: bool, ch_enabled: *bool) void {
        if (length_enable) {
            if (self.timer == 0) return;
            self.timer -= 1;

            // By returning early if timer == 0, this is only
            // true if timer == 0 because of the decrement we just did
            if (self.timer == 0) ch_enabled.* = false;
        }
    }
};

const EnvelopeDevice = struct {
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

const WaveDevice = struct {
    const Self = @This();
    const wave_len = 0x20;
    const tickInterval: u64 = (1 << 24) / (1 << 22);

    buf: [wave_len]u8,
    timer: u16,
    offset: u12,

    sched: *Scheduler,

    pub fn init(sched: *Scheduler) Self {
        return .{
            .buf = [_]u8{0x00} ** wave_len,
            .timer = 0,
            .offset = 0,
            .sched = sched,
        };
    }

    fn reloadTimer(self: *Self, value: u11) void {
        self.sched.removeScheduledEvent(.{ .ApuChannel = 2 });

        self.timer = (@as(u16, 2048) - value) * 2;
        self.sched.push(.{ .ApuChannel = 2 }, @as(u64, self.timer) * tickInterval);
    }

    fn handleTimerOverflow(self: *Self, cnt_freq: io.Frequency, cnt_sel: io.WaveSelect, late: u64) void {
        if (cnt_sel.dimension.read()) {
            self.offset = (self.offset + 1) % 0x40; // 0x20 bytes (both banks), which contain 2 samples each
        } else {
            self.offset = (self.offset + 1) % 0x20; // 0x10 bytes, which contain 2 samples each
        }

        self.timer = (@as(u16, 2048) - cnt_freq.frequency.read()) * 2;
        self.sched.push(.{ .ApuChannel = 2 }, @as(u64, self.timer) * tickInterval -| late);
    }

    fn sample(self: *const Self, cnt: io.WaveSelect) u4 {
        const base = if (cnt.bank.read()) @as(u32, 0x10) else 0;

        const value = self.buf[base + self.offset / 2];
        return if (self.offset & 1 == 0) @truncate(u4, value >> 4) else @truncate(u4, value);
    }

    fn shift(_: *const Self, cnt: io.WaveVolume) u2 {
        return switch (cnt.kind.read()) {
            0b00 => 3, // Mute / Zero
            0b01 => 0, // 100% Volume
            0b10 => 1, // 50% Volume
            0b11 => 2, // 25% Volume
        };
    }

    fn updateLength(_: *Self, fs: *const FrameSequencer, ch3: *Wave, new: io.Frequency) void {
        // Write to NRx4 when FS's next step is not one that clocks the length counter
        if (!fs.isLengthNext()) {
            // If length_enable was disabled but is now enabled and length timer is not 0 already,
            // decrement the length timer

            if (!ch3.freq.length_enable.read() and new.length_enable.read() and ch3.len_dev.timer != 0) {
                ch3.len_dev.timer -= 1;

                // If Length Timer is now 0 and trigger is clear, disable the channel
                if (ch3.len_dev.timer == 0 and !new.trigger.read()) ch3.enabled = false;
            }
        }
    }

    pub fn write(self: *Self, comptime T: type, cnt: io.WaveSelect, addr: u32, value: T) void {
        // TODO: Handle writes when Channel 3 is disabled
        const base = if (!cnt.bank.read()) @as(u32, 0x10) else 0; // Write to the Opposite Bank in Use

        switch (T) {
            u32 => {
                self.buf[base + addr - 0x0400_0090 + 3] = @truncate(u8, value >> 24);
                self.buf[base + addr - 0x0400_0090 + 2] = @truncate(u8, value >> 16);
                self.buf[base + addr - 0x0400_0090 + 1] = @truncate(u8, value >> 8);
                self.buf[base + addr - 0x0400_0090] = @truncate(u8, value);
            },
            u16 => {
                self.buf[base + addr - 0x0400_0090 + 1] = @truncate(u8, value >> 8);
                self.buf[base + addr - 0x0400_0090] = @truncate(u8, value);
            },
            u8 => {
                self.buf[base + addr - 0x0400_0090] = value;
            },
            else => @compileError("Ch3 WAVERAM: Unsupported write width"),
        }
    }
};

const SquareWave = struct {
    const Self = @This();
    const tickInterval: u64 = (1 << 24) / (1 << 22);

    pos: u3,
    sched: *Scheduler,
    timer: u16,

    pub fn init(sched: *Scheduler) Self {
        return .{
            .timer = 0,
            .pos = 0,
            .sched = sched,
        };
    }

    const ChannelKind = enum { Ch1, Ch2 };

    fn updateToneSweepLength(_: *Self, fs: *const FrameSequencer, ch1: *ToneSweep, new: io.Frequency) void {
        // Write to NRx4 when FS's next step is not one that clocks the length counter
        if (!fs.isLengthNext()) {
            // If length_enable was disabled but is now enabled and length timer is not 0 already,
            // decrement the length timer

            if (!ch1.freq.length_enable.read() and new.length_enable.read() and ch1.len_dev.timer != 0) {
                ch1.len_dev.timer -= 1;

                // If Length Timer is now 0 and trigger is clear, disable the channel
                if (ch1.len_dev.timer == 0 and !new.trigger.read()) ch1.enabled = false;
            }
        }
    }

    fn updateToneLength(_: *Self, fs: *const FrameSequencer, ch2: *Tone, new: io.Frequency) void {
        // Write to NRx4 when FS's next step is not one that clocks the length counter
        if (!fs.isLengthNext()) {
            // If length_enable was disabled but is now enabled and length timer is not 0 already,
            // decrement the length timer

            if (!ch2.freq.length_enable.read() and new.length_enable.read() and ch2.len_dev.timer != 0) {
                ch2.len_dev.timer -= 1;

                // If Length Timer is now 0 and trigger is clear, disable the channel
                if (ch2.len_dev.timer == 0 and !new.trigger.read()) ch2.enabled = false;
            }
        }
    }

    fn handleTimerOverflow(self: *Self, comptime kind: ChannelKind, cnt: io.Frequency, late: u64) void {
        self.pos +%= 1;

        self.timer = (@as(u16, 2048) - cnt.frequency.read()) * 4;
        self.sched.push(.{ .ApuChannel = if (kind == .Ch1) 0 else 1 }, @as(u64, self.timer) * tickInterval -| late);
    }

    fn reloadTimer(self: *Self, comptime kind: ChannelKind, value: u11) void {
        self.sched.removeScheduledEvent(.{ .ApuChannel = if (kind == .Ch1) 0 else 1 });

        const tmp = (@as(u16, 2048) - value) * 4; // What Freq Timer should be assuming no weird behaviour
        self.timer = (tmp & ~@as(u16, 0x3)) | self.timer & 0x3; // Keep the last two bits from the old timer;

        self.sched.push(.{ .ApuChannel = if (kind == .Ch1) 0 else 1 }, @as(u64, self.timer) * tickInterval);
    }

    fn sample(self: *const Self, cnt: io.Duty) i8 {
        const pattern = cnt.pattern.read();

        const i = self.pos ^ 7; // index of 0 should get highest bit
        const result = switch (pattern) {
            0b00 => @as(u8, 0b00000001) >> i, // 12.5%
            0b01 => @as(u8, 0b00000011) >> i, // 25%
            0b10 => @as(u8, 0b00001111) >> i, // 50%
            0b11 => @as(u8, 0b11111100) >> i, // 75%
        };

        return if (result & 1 == 1) 1 else -1;
    }
};

// Linear Feedback Shift Register
const Lfsr = struct {
    const Self = @This();
    const tickInterval: u64 = (1 << 24) / (1 << 22);

    shift: u15,
    timer: u16,

    sched: *Scheduler,

    pub fn init(sched: *Scheduler) Self {
        return .{
            .shift = 0,
            .timer = 0,
            .sched = sched,
        };
    }

    fn sample(self: *const Self) i8 {
        return if ((~self.shift & 1) == 1) 1 else -1;
    }

    fn updateLength(_: *Self, fs: *const FrameSequencer, ch4: *Noise, new: io.NoiseControl) void {
        // Write to NRx4 when FS's next step is not one that clocks the length counter
        if (!fs.isLengthNext()) {
            // If length_enable was disabled but is now enabled and length timer is not 0 already,
            // decrement the length timer

            if (!ch4.cnt.length_enable.read() and new.length_enable.read() and ch4.len_dev.timer != 0) {
                ch4.len_dev.timer -= 1;

                // If Length Timer is now 0 and trigger is clear, disable the channel
                if (ch4.len_dev.timer == 0 and !new.trigger.read()) ch4.enabled = false;
            }
        }
    }

    fn reloadTimer(self: *Self, poly: io.PolyCounter) void {
        self.sched.removeScheduledEvent(.{ .ApuChannel = 3 });

        const div = Self.divisor(poly.div_ratio.read());
        const timer = div << poly.shift.read();
        self.sched.push(.{ .ApuChannel = 3 }, @as(u64, timer) * tickInterval);
    }

    fn handleTimerOverflow(self: *Self, poly: io.PolyCounter, late: u64) void {
        // Obscure: "Using a noise channel clock shift of 14 or 15
        // results in the LFSR receiving no clocks."
        if (poly.shift.read() >= 14) return;

        const div = Self.divisor(poly.div_ratio.read());
        const timer = div << poly.shift.read();

        const tmp = (self.shift & 1) ^ ((self.shift & 2) >> 1);
        self.shift = (self.shift >> 1) | (tmp << 14);

        if (poly.width.read())
            self.shift = (self.shift & ~@as(u15, 0x40)) | tmp << 6;

        self.sched.push(.{ .ApuChannel = 3 }, @as(u64, timer) * tickInterval -| late);
    }

    fn divisor(code: u3) u16 {
        if (code == 0) return 8;
        return @as(u16, code) << 4;
    }
};
