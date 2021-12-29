const std = @import("std");


pub fn u32_sign_extend(value: u32, bitSize: anytype) u32 {
    const amount: u5 = 32 - bitSize;
    return @bitCast(u32, @bitCast(i32, value << amount) >> amount);
}
