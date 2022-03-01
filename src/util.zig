const std = @import("std");

pub fn sext(comptime bits: comptime_int, value: u32) u32 {
    comptime std.debug.assert(bits <= 32);
    const amount = 32 - bits;

    return @bitCast(u32, @bitCast(i32, value << amount) >> amount);
}
