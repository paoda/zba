const io = @import("../bus/io.zig");
const util = @import("../../util.zig");

const Scheduler = @import("../scheduler.zig").Scheduler;
const FrameSequencer = @import("../apu.zig").FrameSequencer;
const Tick = @import("../apu.zig").Apu.Tick;
const Length = @import("device/Length.zig");
const Envelope = @import("device/Envelope.zig");
const Square = @import("signal/Square.zig");

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
/// FrequencyTimer Functionality
square: Square,

enabled: bool,
sample: i8,

pub fn init(sched: *Scheduler) Self {
    return .{
        .duty = .{ .raw = 0 },
        .envelope = .{ .raw = 0 },
        .freq = .{ .raw = 0 },
        .enabled = false,

        .square = Square.init(sched),
        .len_dev = Length.create(),
        .env_dev = Envelope.create(),

        .sample = 0,
    };
}

pub fn reset(self: *Self) void {
    self.duty.raw = 0;
    self.envelope.raw = 0;
    self.freq.raw = 0;

    self.sample = 0;
    self.enabled = false;
}

pub fn tick(self: *Self, comptime kind: Tick) void {
    switch (kind) {
        .Length => self.len_dev.tick(self.freq.length_enable.read(), &self.enabled),
        .Envelope => self.env_dev.tick(self.envelope),
        .Sweep => @compileError("Channel 2 does not implement Sweep"),
    }
}

pub fn onToneEvent(self: *Self, late: u64) void {
    self.square.onSquareTimerExpire(Self, self.freq, late);

    self.sample = 0;
    if (!self.isDacEnabled()) return;
    self.sample = if (self.enabled) self.square.sample(self.duty) * @as(i8, self.env_dev.vol) else 0;
}

/// NR21, NR22
pub fn getSoundCntL(self: *const Self) u16 {
    return @as(u16, self.envelope.raw) << 8 | (self.duty.raw & 0xC0);
}

/// NR21, NR22
pub fn setSoundCntL(self: *Self, value: u16) void {
    self.setNr21(@truncate(u8, value));
    self.setNr22(@truncate(u8, value >> 8));
}

/// NR21
pub fn setNr21(self: *Self, value: u8) void {
    self.duty.raw = value;
    self.len_dev.timer = @as(u7, 64) - @truncate(u6, value);
}

/// NR22
pub fn setNr22(self: *Self, value: u8) void {
    self.envelope.raw = value;
    if (!self.isDacEnabled()) self.enabled = false;
}

/// NR23, NR24
pub fn getSoundCntH(self: *const Self) u16 {
    return self.freq.raw & 0x4000;
}

/// NR23, NR24
pub fn setSoundCntH(self: *Self, fs: *const FrameSequencer, value: u16) void {
    self.setNr23(@truncate(u8, value));
    self.setNr24(fs, @truncate(u8, value >> 8));
}

/// NR23
pub fn setNr23(self: *Self, byte: u8) void {
    self.freq.raw = (self.freq.raw & 0xFF00) | byte;
}

/// NR24
pub fn setNr24(self: *Self, fs: *const FrameSequencer, byte: u8) void {
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

        self.enabled = self.isDacEnabled();
    }

    util.audio.length.update(Self, self, fs, new);
    self.freq = new;
}

fn isDacEnabled(self: *const Self) bool {
    return self.envelope.raw & 0xF8 != 0;
}
