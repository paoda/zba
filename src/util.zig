const std = @import("std");

pub fn sext(comptime bits: comptime_int, value: u32) u32 {
    comptime std.debug.assert(bits <= 32);
    const amount = 32 - bits;

    return @bitCast(u32, @bitCast(i32, value << amount) >> amount);
}

pub const FpsAverage = struct {
    const Self = @This();

    total: u64,
    sample_count: u64,

    pub fn init() Self {
        return .{ .total = 0, .sample_count = 0 };
    }

    pub fn add(self: *Self, sample: u64) void {
        if (self.sample_count == 1000) return self.reset(sample);

        self.total += sample;
        self.sample_count += 1;
    }

    pub fn calc(self: *const Self) u64 {
        return self.total / self.sample_count;
    }

    fn reset(self: *Self, sample: u64) void {
        self.total = sample;
        self.sample_count = 1;
    }
};
