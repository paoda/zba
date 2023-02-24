const Self = @This();

timer: u9 = 0,

pub fn create() Self {
    return .{};
}

pub fn reset(self: *Self) void {
    self.* = .{};
}

pub fn tick(self: *Self, enabled: bool, ch_enable: *bool) void {
    if (enabled) {
        if (self.timer == 0) return;
        self.timer -= 1;

        // By returning early if timer == 0, this is only
        // true if timer == 0 because of the decrement we just did
        if (self.timer == 0) ch_enable.* = false;
    }
}
