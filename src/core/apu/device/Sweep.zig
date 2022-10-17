const io = @import("../../bus/io.zig");
const ToneSweep = @import("../ToneSweep.zig");

const Self = @This();

timer: u8,
enabled: bool,
shadow: u11,

calc_performed: bool,

pub fn create() Self {
    return .{
        .timer = 0,
        .enabled = false,
        .shadow = 0,
        .calc_performed = false,
    };
}

pub fn tick(self: *Self, ch1: *ToneSweep) void {
    if (self.timer != 0) self.timer -= 1;

    if (self.timer == 0) {
        const period = ch1.sweep.period.read();
        self.timer = if (period == 0) 8 else period;
        if (!self.calc_performed) self.calc_performed = true;

        if (self.enabled and period != 0) {
            const new_freq = self.calculate(ch1.sweep, &ch1.enabled);

            if (new_freq <= 0x7FF and ch1.sweep.shift.read() != 0) {
                ch1.freq.frequency.write(@truncate(u11, new_freq));
                self.shadow = @truncate(u11, new_freq);

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

    const freq = if (decrease) shadow - shadow_shifted else shadow + shadow_shifted;
    if (freq > 0x7FF) ch_enable.* = false;

    return freq;
}