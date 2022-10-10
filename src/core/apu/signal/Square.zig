const std = @import("std");
const io = @import("../../bus/io.zig");

const Scheduler = @import("../../scheduler.zig").Scheduler;
const FrameSequencer = @import("../../apu.zig").FrameSequencer;
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

/// Updates the State of either Ch1 or Ch2's Length Timer
pub fn updateLength(_: *const Self, comptime T: type, fs: *const FrameSequencer, ch: *T, nrx34: io.Frequency) void {
    comptime std.debug.assert(T == ToneSweep or T == Tone);
    // Write to NRx4 when FS's next step is not one that clocks the length counter
    if (!fs.isLengthNext()) {
        // If length_enable was disabled but is now enabled and length timer is not 0 already,
        // decrement the length timer

        if (!ch.freq.length_enable.read() and nrx34.length_enable.read() and ch.len_dev.timer != 0) {
            ch.len_dev.timer -= 1;

            // If Length Timer is now 0 and trigger is clear, disable the channel
            if (ch.len_dev.timer == 0 and !nrx34.trigger.read()) ch.enabled = false;
        }
    }
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
