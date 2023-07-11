const io = @import("../../bus/io.zig");
const ToneSweep = @import("../ToneSweep.zig");

const Self = @This();

timer: u8 = 0,
enabled: bool = false,
shadow: u11 = 0,

calc_performed: bool = false,

pub fn create() Self {
    return .{};
}

pub fn reset(self: *Self) void {
    self.* = .{};
}

pub fn tick(self: *Self, ch1: *ToneSweep) void {
    if (self.timer != 0) self.timer -= 1;

    if (self.timer == 0) {
        const period = ch1.sweep.period.read();
        self.timer = if (period == 0) 8 else period;

        if (self.enabled and period != 0) {
            const new_freq = self.calculate(ch1.sweep, &ch1.enabled);

            if (new_freq <= 0x7FF and ch1.sweep.shift.read() != 0) {
                ch1.freq.frequency.write(@as(u11, @truncate(new_freq)));
                self.shadow = @as(u11, @truncate(new_freq));

                _ = self.calculate(ch1.sweep, &ch1.enabled);
            }
        }
    }
}

/// Calculates the Sweep Frequency
pub fn calculate(self: *Self, sweep: io.Sweep, ch_enable: *bool) u12 {
    const shadow = @as(u12, self.shadow);
    const shadow_shifted = shadow >> sweep.shift.read();
    const decrease = sweep.direction.read();

    const freq = if (decrease) blk: {
        self.calc_performed = true;
        break :blk shadow - shadow_shifted;
    } else shadow + shadow_shifted;
    if (freq > 0x7FF) ch_enable.* = false;

    return freq;
}
