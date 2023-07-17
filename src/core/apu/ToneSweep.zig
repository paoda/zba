const io = @import("../bus/io.zig");
const util = @import("../../util.zig");

const Scheduler = @import("../scheduler.zig").Scheduler;
const FrameSequencer = @import("../apu.zig").FrameSequencer;
const Length = @import("device/Length.zig");
const Envelope = @import("device/Envelope.zig");
const Sweep = @import("device/Sweep.zig");
const Square = @import("signal/Square.zig");

const Tick = @import("../apu.zig").Apu.Tick;

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
square: Square,
enabled: bool,

sample: i8,

pub fn init(sched: *Scheduler) Self {
    return .{
        .sweep = .{ .raw = 0 },
        .duty = .{ .raw = 0 },
        .envelope = .{ .raw = 0 },
        .freq = .{ .raw = 0 },
        .sample = 0,
        .enabled = false,

        .square = Square.init(sched),
        .len_dev = Length.create(),
        .sweep_dev = Sweep.create(),
        .env_dev = Envelope.create(),
    };
}

pub fn reset(self: *Self) void {
    self.sweep.raw = 0; // NR10
    self.duty.raw = 0; // NR11
    self.envelope.raw = 0; // NR12
    self.freq.raw = 0; // NR13, NR14

    self.len_dev.reset();
    self.sweep_dev.reset();
    self.env_dev.reset();

    self.sample = 0;
    self.enabled = false;
}

pub fn tick(self: *Self, comptime kind: Tick) void {
    switch (kind) {
        .Length => self.len_dev.tick(self.freq.length_enable.read(), &self.enabled),
        .Envelope => self.env_dev.tick(self.envelope),
        .Sweep => self.sweep_dev.tick(self),
    }
}

pub fn onToneSweepEvent(self: *Self, late: u64) void {
    self.square.onSquareTimerExpire(Self, self.freq, late);

    self.sample = 0;
    if (!self.isDacEnabled()) return;
    self.sample = if (self.enabled) self.square.sample(self.duty) * @as(i8, self.env_dev.vol) else 0;
}

/// NR10, NR11, NR12
pub fn setSound1Cnt(self: *Self, value: u32) void {
    self.setSound1CntL(@truncate(value));
    self.setSound1CntH(@truncate(value >> 16));
}

/// NR10
pub fn sound1CntL(self: *const Self) u8 {
    return self.sweep.raw & 0x7F;
}

/// NR10
pub fn setSound1CntL(self: *Self, value: u8) void {
    const new = io.Sweep{ .raw = value };

    if (!new.direction.read()) {
        // If at least one (1) sweep calculation has been made with
        // the negate bit set (since last trigger), disable the channel

        if (self.sweep_dev.calc_performed) self.enabled = false;
    }

    self.sweep.raw = value;
}

/// NR11, NR12
pub fn sound1CntH(self: *const Self) u16 {
    return @as(u16, self.envelope.raw) << 8 | (self.duty.raw & 0xC0);
}

/// NR11, NR12
pub fn setSound1CntH(self: *Self, value: u16) void {
    self.setNr11(@truncate(value));
    self.setNr12(@truncate(value >> 8));
}

/// NR11
pub fn setNr11(self: *Self, value: u8) void {
    self.duty.raw = value;
    self.len_dev.timer = @as(u7, 64) - @as(u6, @truncate(value));
}

/// NR12
pub fn setNr12(self: *Self, value: u8) void {
    self.envelope.raw = value;
    if (!self.isDacEnabled()) self.enabled = false;
}

/// NR13, NR14
pub fn sound1CntX(self: *const Self) u16 {
    return self.freq.raw & 0x4000;
}

/// NR13, NR14
pub fn setSound1CntX(self: *Self, fs: *const FrameSequencer, value: u16) void {
    self.setNr13(@truncate(value));
    self.setNr14(fs, @truncate(value >> 8));
}

/// NR13
pub fn setNr13(self: *Self, byte: u8) void {
    self.freq.raw = (self.freq.raw & 0xFF00) | byte;
}

/// NR14
pub fn setNr14(self: *Self, fs: *const FrameSequencer, byte: u8) void {
    var new: io.Frequency = .{ .raw = (@as(u16, byte) << 8) | (self.freq.raw & 0xFF) };

    if (new.trigger.read()) {
        self.enabled = true;

        if (self.len_dev.timer == 0) {
            self.len_dev.timer =
                if (!fs.isLengthNext() and new.length_enable.read()) 63 else 64;
        }

        self.square.reload(Self, self.freq.frequency.read());

        // Reload Envelope period and timer
        self.env_dev.timer = self.envelope.period.read();
        if (fs.isEnvelopeNext() and self.env_dev.timer != 0b111) self.env_dev.timer += 1;

        self.env_dev.vol = self.envelope.init_vol.read();

        // Sweep Trigger Behaviour
        const sw_period = self.sweep.period.read();
        const sw_shift = self.sweep.shift.read();

        self.sweep_dev.calc_performed = false;
        self.sweep_dev.shadow = self.freq.frequency.read();
        self.sweep_dev.timer = if (sw_period == 0) 8 else sw_period;
        self.sweep_dev.enabled = sw_period != 0 or sw_shift != 0;
        if (sw_shift != 0) _ = self.sweep_dev.calculate(self.sweep, &self.enabled);

        self.enabled = self.isDacEnabled();
    }

    util.audio.length.update(Self, self, fs, new);
    self.freq = new;
}

fn isDacEnabled(self: *const Self) bool {
    return self.envelope.raw & 0xF8 != 0;
}
