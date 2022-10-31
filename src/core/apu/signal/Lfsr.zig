//! Linear Feedback Shift Register
const io = @import("../../bus/io.zig");

const Scheduler = @import("../../scheduler.zig").Scheduler;

const Self = @This();
pub const interval: u64 = (1 << 24) / (1 << 22);

shift: u15,
timer: u16,

sched: *Scheduler,

pub fn create(sched: *Scheduler) Self {
    return .{
        .shift = 0,
        .timer = 0,
        .sched = sched,
    };
}

pub fn sample(self: *const Self) i8 {
    return if ((~self.shift & 1) == 1) 1 else -1;
}

/// Reload LFSR Timer
pub fn reload(self: *Self, poly: io.PolyCounter) void {
    self.sched.removeScheduledEvent(.{ .ApuChannel = 3 });

    const div = Self.divisor(poly.div_ratio.read());
    const timer = div << poly.shift.read();
    self.sched.push(.{ .ApuChannel = 3 }, @as(u64, timer) * interval);
}

/// Scheduler Event Handler for LFSR Timer Expire
/// FIXME: This gets called a lot, slowing down the scheduler
pub fn onLfsrTimerExpire(self: *Self, poly: io.PolyCounter, late: u64) void {
    // Obscure: "Using a noise channel clock shift of 14 or 15
    // results in the LFSR receiving no clocks."
    if (poly.shift.read() >= 14) return;

    const div = Self.divisor(poly.div_ratio.read());
    const timer = div << poly.shift.read();

    const tmp = (self.shift & 1) ^ ((self.shift & 2) >> 1);
    self.shift = (self.shift >> 1) | (tmp << 14);

    if (poly.width.read())
        self.shift = (self.shift & ~@as(u15, 0x40)) | tmp << 6;

    self.sched.push(.{ .ApuChannel = 3 }, @as(u64, timer) * interval -| late);
}

fn divisor(code: u3) u16 {
    if (code == 0) return 8;
    return @as(u16, code) << 4;
}
