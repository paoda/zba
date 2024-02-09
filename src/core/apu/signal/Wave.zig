const std = @import("std");
const io = @import("../../bus/io.zig");

const Scheduler = @import("../../scheduler.zig").Scheduler;

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
    return std.mem.readInt(T, self.buf[i..][0..@sizeOf(T)], .little);
}

pub fn write(self: *Self, comptime T: type, nr30: io.WaveSelect, addr: u32, value: T) void {
    // TODO: Handle writes when Channel 3 is disabled
    const base = if (!nr30.bank.read()) @as(u32, 0x10) else 0; // Write to the Opposite Bank in Use

    const i = base + addr - 0x0400_0090;
    std.mem.writeInt(T, self.buf[i..][0..@sizeOf(T)], value, .little);
}

pub fn init(sched: *Scheduler) Self {
    return .{
        .buf = [_]u8{0x00} ** buf_len,
        .timer = 0,
        .offset = 0,
        .sched = sched,
    };
}

pub fn reset(self: *Self) void {
    self.timer = 0;
    self.offset = 0;

    // sample buffer isn't reset because it's outside of the range of what NR52{7}'s effects
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
    return if (self.offset & 1 == 0) @truncate(value >> 4) else @truncate(value);
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
