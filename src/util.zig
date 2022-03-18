const std = @import("std");
const Log2Int = std.math.Log2Int;

pub inline fn sext(comptime bits: comptime_int, value: u32) u32 {
    comptime std.debug.assert(bits <= 32);
    const amount = 32 - bits;

    return @bitCast(u32, @bitCast(i32, value << amount) >> amount);
}

/// See https://godbolt.org/z/W3en9Eche
pub inline fn rotr(comptime T: type, value: T, r: anytype) T {
    comptime std.debug.assert(@typeInfo(T).Int.signedness == .unsigned);
    const ar = @truncate(Log2Int(T), r);

    return value >> ar | value << @truncate(Log2Int(T), @typeInfo(T).Int.bits - @as(T, ar));
}

pub const FpsAverage = struct {
    const Self = @This();

    total: u64,
    sample_count: u64,

    pub fn init() Self {
        return .{ .total = 0, .sample_count = 1 };
    }

    pub fn add(self: *Self, sample: u64) void {
        if (self.sample_count == 600) return self.reset(sample);

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

pub fn intToBytes(comptime T: type, value: anytype) [@sizeOf(T)]u8 {
    comptime std.debug.assert(@typeInfo(T) == .Int);

    var result: [@sizeOf(T)]u8 = undefined;

    var i: Log2Int(T) = 0;
    while (i < result.len) : (i += 1) result[i] = @truncate(u8, value >> i * @bitSizeOf(u8));

    return result;
}
