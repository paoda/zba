const std = @import("std");
const io = @import("../../bus/io.zig");

const Scheduler = @import("../../scheduler.zig").Scheduler;
const FrameSequencer = @import("../../apu.zig").FrameSequencer;
const Wave = @import("../Wave.zig");

const buf_len = 0x20;
pub const interval: u64 = (1 << 24) / (1 << 22);
const Self = @This();

buf: [buf_len]u8,
timer: u16,
offset: u12,

sched: *Scheduler,

pub fn read(self: *const Self, comptime T: type, nr30: io.WaveSelect, addr: u32) T {
    // TODO: Handle reads when Channel 3 is disabled
    const base = if (!nr30.bank.read()) @as(u32, 0x10) else 0; // Read from the Opposite Bank in Use

    const i = base + addr - 0x0400_0090;
    return std.mem.readIntSliceLittle(T, self.buf[i..][0..@sizeOf(T)]);
}

pub fn write(self: *Self, comptime T: type, nr30: io.WaveSelect, addr: u32, value: T) void {
    // TODO: Handle writes when Channel 3 is disabled
    const base = if (!nr30.bank.read()) @as(u32, 0x10) else 0; // Write to the Opposite Bank in Use

    const i = base + addr - 0x0400_0090;
    std.mem.writeIntSliceLittle(T, self.buf[i..][0..@sizeOf(T)], value);
}

pub fn init(sched: *Scheduler) Self {
    return .{
        .buf = [_]u8{0x00} ** buf_len,
        .timer = 0,
        .offset = 0,
        .sched = sched,
    };
}

/// Reload internal Wave Timer
pub fn reload(self: *Self, value: u11) void {
    self.sched.removeScheduledEvent(.{ .ApuChannel = 2 });

    self.timer = (@as(u16, 2048) - value) * 2;
    self.sched.push(.{ .ApuChannel = 2 }, @as(u64, self.timer) * interval);
}

/// Scheduler Event Handler
pub fn onWaveTimerExpire(self: *Self, nrx34: io.Frequency, nr30: io.WaveSelect, late: u64) void {
    if (nr30.dimension.read()) {
        self.offset = (self.offset + 1) % 0x40; // 0x20 bytes (both banks), which contain 2 samples each
    } else {
        self.offset = (self.offset + 1) % 0x20; // 0x10 bytes, which contain 2 samples each
    }

    self.timer = (@as(u16, 2048) - nrx34.frequency.read()) * 2;
    self.sched.push(.{ .ApuChannel = 2 }, @as(u64, self.timer) * interval -| late);
}

/// Generate Sample from Wave Synth
pub fn sample(self: *const Self, nr30: io.WaveSelect) u4 {
    const base = if (nr30.bank.read()) @as(u32, 0x10) else 0;

    const value = self.buf[base + self.offset / 2];
    return if (self.offset & 1 == 0) @truncate(u4, value >> 4) else @truncate(u4, value);
}

/// TODO: Write comment
pub fn shift(_: *const Self, nr32: io.WaveVolume) u2 {
    return switch (nr32.kind.read()) {
        0b00 => 3, // Mute / Zero
        0b01 => 0, // 100% Volume
        0b10 => 1, // 50% Volume
        0b11 => 2, // 25% Volume
    };
}

/// Update state of Channel 3 Length Device
pub fn updateLength(_: *Self, fs: *const FrameSequencer, ch3: *Wave, nrx34: io.Frequency) void {
    // Write to NRx4 when FS's next step is not one that clocks the length counter
    if (!fs.isLengthNext()) {
        // If length_enable was disabled but is now enabled and length timer is not 0 already,
        // decrement the length timer

        if (!ch3.freq.length_enable.read() and nrx34.length_enable.read() and ch3.len_dev.timer != 0) {
            ch3.len_dev.timer -= 1;

            // If Length Timer is now 0 and trigger is clear, disable the channel
            if (ch3.len_dev.timer == 0 and !nrx34.trigger.read()) ch3.enabled = false;
        }
    }
}
