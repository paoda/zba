const std = @import("std");

pub fn signExtend(comptime T: type, comptime bits: usize, value: anytype) T {
    const ValT = comptime @TypeOf(value);
    comptime std.debug.assert(isInteger(ValT));
    comptime std.debug.assert(isSigned(ValT));

    const value_bits = @typeInfo(ValT).Int.bits;
    comptime std.debug.assert(value_bits >= bits);

    const bit_diff = value_bits - bits;

    // (1 << bits) -1 is a mask that will take values like 0x100 and make them 0xFF
    // value & mask so that only the relevant bits are sign extended
    // therefore, value & ((1 << bits) - 1) is the isolation of the relevant bits
    return ((value & ((1 << bits) - 1)) << bit_diff) >> bit_diff;
}

pub fn u32SignExtend(comptime bits: usize, value: u32) u32 {
    return @bitCast(u32, signExtend(i32, bits, @bitCast(i32, value)));
}

fn isInteger(comptime T: type) bool {
    return @typeInfo(T) == .Int;
}

fn isSigned(comptime T: type) bool {
    return @typeInfo(T).Int.signedness == .signed;
}
