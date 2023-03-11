const io = @import("../../bus/io.zig");

const Self = @This();

/// Period Timer
timer: u3 = 0,
/// Current Volume
vol: u4 = 0,

pub fn create() Self {
    return .{};
}

pub fn reset(self: *Self) void {
    self.* = .{};
}

pub fn tick(self: *Self, nrx2: io.Envelope) void {
    if (nrx2.period.read() != 0) {
        if (self.timer != 0) self.timer -= 1;

        if (self.timer == 0) {
            self.timer = nrx2.period.read();

            if (nrx2.direction.read()) {
                if (self.vol < 0xF) self.vol += 1;
            } else {
                if (self.vol > 0x0) self.vol -= 1;
            }
        }
    }
}
