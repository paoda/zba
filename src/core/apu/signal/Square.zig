const std = @import("std");
const io = @import("../../bus/io.zig");

const Scheduler = @import("../../scheduler.zig").Scheduler;
const ToneSweep = @import("../ToneSweep.zig");
const Tone = @import("../Tone.zig");

const Self = @This();
pub const interval: u64 = (1 << 24) / (1 << 22);

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

pub fn reset(self: *Self) void {
    self.timer = 0;
    self.pos = 0;
}

/// Scheduler Event Handler for Square Synth Timer Expire
pub fn onSquareTimerExpire(self: *Self, comptime T: type, nrx34: io.Frequency, late: u64) void {
    comptime std.debug.assert(T == ToneSweep or T == Tone);
    self.pos +%= 1;

    self.timer = (@as(u16, 2048) - nrx34.frequency.read()) * 4;
    self.sched.push(.{ .ApuChannel = if (T == ToneSweep) 0 else 1 }, @as(u64, self.timer) * interval -| late);
}

/// Reload Square Wave Timer
pub fn reload(self: *Self, comptime T: type, value: u11) void {
    comptime std.debug.assert(T == ToneSweep or T == Tone);
    const channel = if (T == ToneSweep) 0 else 1;

    self.sched.removeScheduledEvent(.{ .ApuChannel = channel });

    const tmp = (@as(u16, 2048) - value) * 4; // What Freq Timer should be assuming no weird behaviour
    self.timer = (tmp & ~@as(u16, 0x3)) | self.timer & 0x3; // Keep the last two bits from the old timer;

    self.sched.push(.{ .ApuChannel = channel }, @as(u64, self.timer) * interval);
}

pub fn sample(self: *const Self, nrx1: io.Duty) i8 {
    const pattern = nrx1.pattern.read();

    const i = self.pos ^ 7; // index of 0 should get highest bit
    const result = switch (pattern) {
        0b00 => @as(u8, 0b00000001) >> i, // 12.5%
        0b01 => @as(u8, 0b00000011) >> i, // 25%
        0b10 => @as(u8, 0b00001111) >> i, // 50%
        0b11 => @as(u8, 0b11111100) >> i, // 75%
    };

    return if (result & 1 == 1) 1 else -1;
}
