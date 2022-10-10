const io = @import("../bus/io.zig");

const Scheduler = @import("../scheduler.zig").Scheduler;
const FrameSequencer = @import("../apu.zig").FrameSequencer;
const Envelope = @import("device/Envelope.zig");
const Length = @import("device/Length.zig");
const Lfsr = @import("signal/Lfsr.zig");

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

// Linear Feedback Shift Register
lfsr: Lfsr,

enabled: bool,
sample: i8,

pub fn init(sched: *Scheduler) Self {
    return .{
        .len = 0,
        .envelope = .{ .raw = 0 },
        .poly = .{ .raw = 0 },
        .cnt = .{ .raw = 0 },
        .enabled = false,

        .len_dev = Length.create(),
        .env_dev = Envelope.create(),
        .lfsr = Lfsr.create(sched),

        .sample = 0,
    };
}

pub fn reset(self: *Self) void {
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

/// NR41, NR42
pub fn getSoundCntL(self: *const Self) u16 {
    return @as(u16, self.envelope.raw) << 8;
}

/// NR41, NR42
pub fn setSoundCntL(self: *Self, value: u16) void {
    self.setNr41(@truncate(u8, value));
    self.setNr42(@truncate(u8, value >> 8));
}

/// NR41
pub fn setNr41(self: *Self, len: u8) void {
    self.len = @truncate(u6, len);
    self.len_dev.timer = @as(u7, 64) - @truncate(u6, len);
}

/// NR42
pub fn setNr42(self: *Self, value: u8) void {
    self.envelope.raw = value;
    if (!self.isDacEnabled()) self.enabled = false;
}

/// NR43, NR44
pub fn getSoundCntH(self: *const Self) u16 {
    return @as(u16, self.poly.raw & 0x40) << 8 | self.cnt.raw;
}

/// NR43, NR44
pub fn setSoundCntH(self: *Self, fs: *const FrameSequencer, value: u16) void {
    self.poly.raw = @truncate(u8, value);
    self.setNr44(fs, @truncate(u8, value >> 8));
}

/// NR44
pub fn setNr44(self: *Self, fs: *const FrameSequencer, byte: u8) void {
    var new: io.NoiseControl = .{ .raw = byte };

    if (new.trigger.read()) {
        self.enabled = true;

        if (self.len_dev.timer == 0) {
            self.len_dev.timer =
                if (!fs.isLengthNext() and new.length_enable.read()) 63 else 64;
        }

        // Update The Frequency Timer
        self.lfsr.reload(self.poly);
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
    self.lfsr.onLfsrTimerExpire(self.poly, late);

    self.sample = 0;
    if (!self.isDacEnabled()) return;
    self.sample = if (self.enabled) self.lfsr.sample() * @as(i8, self.env_dev.vol) else 0;
}

pub fn amplitude(self: *const Self) i16 {
    return @as(i16, self.sample);
}

fn isDacEnabled(self: *const Self) bool {
    return self.envelope.raw & 0xF8 != 0x00;
}
