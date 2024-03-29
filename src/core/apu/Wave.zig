const io = @import("../bus/io.zig");
const util = @import("../../util.zig");

const Scheduler = @import("../scheduler.zig").Scheduler;
const FrameSequencer = @import("../apu.zig").FrameSequencer;
const Tick = @import("../apu.zig").Apu.Tick;

const Length = @import("device/Length.zig");
const Wave = @import("signal/Wave.zig");

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
wave_dev: Wave,

enabled: bool,
sample: i8,

pub fn init(sched: *Scheduler) Self {
    return .{
        .select = .{ .raw = 0 },
        .vol = .{ .raw = 0 },
        .freq = .{ .raw = 0 },
        .length = 0,

        .len_dev = Length.create(),
        .wave_dev = Wave.init(sched),
        .enabled = false,
        .sample = 0,
    };
}

pub fn reset(self: *Self) void {
    self.select.raw = 0; // NR30
    self.length = 0; // NR31
    self.vol.raw = 0; // NR32
    self.freq.raw = 0; // NR33, NR34

    self.len_dev.reset();
    self.wave_dev.reset();

    self.sample = 0;
    self.enabled = false;
}

pub fn tick(self: *Self, comptime kind: Tick) void {
    switch (kind) {
        .Length => self.len_dev.tick(self.freq.length_enable.read(), &self.enabled),
        .Envelope => @compileError("Channel 3 does not implement Envelope"),
        .Sweep => @compileError("Channel 3 does not implement Sweep"),
    }
}

/// NR30, NR31, NR32
pub fn setSound3Cnt(self: *Self, value: u32) void {
    self.setSound3CntL(@truncate(value));
    self.setSound3CntH(@truncate(value >> 16));
}

/// NR30
pub fn setSound3CntL(self: *Self, value: u8) void {
    self.select.raw = value;
    if (!self.select.enabled.read()) self.enabled = false;
}

/// NR30
pub fn sound3CntL(self: *const Self) u8 {
    return self.select.raw & 0xE0;
}

/// NR31, NR32
pub fn sound3CntH(self: *const Self) u16 {
    return @as(u16, self.length & 0xE0) << 8;
}

/// NR31, NR32
pub fn setSound3CntH(self: *Self, value: u16) void {
    self.setNr31(@truncate(value));
    self.vol.raw = @truncate(value >> 8);
}

/// NR31
pub fn setNr31(self: *Self, len: u8) void {
    self.length = len;
    self.len_dev.timer = 256 - @as(u9, len);
}

/// NR33, NR34
pub fn setSound3CntX(self: *Self, fs: *const FrameSequencer, value: u16) void {
    self.setNr33(@truncate(value));
    self.setNr34(fs, @truncate(value >> 8));
}

/// NR33, NR34
pub fn sound3CntX(self: *const Self) u16 {
    return self.freq.raw & 0x4000;
}

/// NR33
pub fn setNr33(self: *Self, byte: u8) void {
    self.freq.raw = (self.freq.raw & 0xFF00) | byte;
}

/// NR34
pub fn setNr34(self: *Self, fs: *const FrameSequencer, byte: u8) void {
    var new: io.Frequency = .{ .raw = (@as(u16, byte) << 8) | (self.freq.raw & 0xFF) };

    if (new.trigger.read()) {
        self.enabled = true;

        if (self.len_dev.timer == 0) {
            self.len_dev.timer =
                if (!fs.isLengthNext() and new.length_enable.read()) 255 else 256;
        }

        // Update The Frequency Timer
        self.wave_dev.reload(self.freq.frequency.read());
        self.wave_dev.offset = 0;

        self.enabled = self.select.enabled.read();
    }

    util.audio.length.update(Self, self, fs, new);
    self.freq = new;
}

pub fn onWaveEvent(self: *Self, late: u64) void {
    self.wave_dev.onWaveTimerExpire(self.freq, self.select, late);

    self.sample = 0;
    if (!self.select.enabled.read()) return;
    // Convert unsigned 4-bit wave sample to signed 8-bit sample
    self.sample = (2 * @as(i8, self.wave_dev.sample(self.select)) - 15) >> self.wave_dev.shift(self.vol);
}
