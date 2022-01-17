const std = @import("std");

const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const CPSR = @import("../../cpu.zig").PSR;

pub fn exec(comptime S: bool, cpu: *Arm7tdmi, opcode: u32) u32 {
    var shift_amt: u8 = undefined;
    if (opcode >> 4 & 1 == 1) {
        shift_amt = @truncate(u8, cpu.r[opcode >> 8 & 0xF]);
    } else {
        shift_amt = @truncate(u8, opcode >> 7 & 0x1F);
    }

    const rm = cpu.r[opcode & 0xF];
    var value: u32 = undefined;
    if (rm == 0xF) {
        value = cpu.fakePC() + 4; // 12 ahead
    } else {
        value = cpu.r[opcode & 0xF];
    }

    return switch (@truncate(u2, opcode >> 5)) {
        0b00 => logicalLeft(S, &cpu.cpsr, value, shift_amt),
        0b01 => logicalRight(S, &cpu.cpsr, value, shift_amt),
        0b10 => arithmeticRight(S, &cpu.cpsr, value, shift_amt),
        0b11 => rotateRight(S, &cpu.cpsr, value, shift_amt),
    };
}

pub fn logicalLeft(comptime S: bool, cpsr: *CPSR, rm: u32, amount: u8) u32 {
    const shift_amt = @truncate(u5, amount);
    const bit_count: u8 = @typeInfo(u32).Int.bits;

    var result: u32 = 0x0000_0000;

    if (amount < bit_count) {
        // We can perform a well-defined shift here

        // FIXME: We assume cpu.r[rs] == 0 and imm_shift == 0 are equivalent
        if (S and shift_amt != 0) {
            const carry_bit = @truncate(u5, bit_count - shift_amt);
            cpsr.c.write(rm >> carry_bit & 1 == 1);
        }

        result = rm << shift_amt;
    } else if (amount == bit_count) {
        // Shifted all bits out, carry bit is bit 0 of rm
        if (S) cpsr.c.write(rm & 1 == 1);
    } else {
        // Shifted all bits out, carry bit has also been shifted out
        if (S) cpsr.c.write(false);
    }

    return result;
}

pub fn logicalRight(comptime S: bool, cpsr: *CPSR, rm: u32, amount: u32) u32 {
    const shift_amt = @truncate(u5, amount);
    const bit_count: u8 = @typeInfo(u32).Int.bits;

    var result: u32 = 0x0000_0000;

    if (amount == 0 or amount == bit_count) {
        // Actualy LSR #32
        if (S) cpsr.c.write(rm >> 31 & 1 == 1);
    } else if (amount < bit_count) {
        // We can perform a well-defined shift
        const carry_bit = shift_amt - 1;
        if (S) cpsr.c.write(rm >> carry_bit & 1 == 1);

        result = rm >> shift_amt;
    } else {
        // All bits have been shifted out, including carry bit
        if (S) cpsr.c.write(false);
    }

    return result;
}

pub fn arithmeticRight(comptime _: bool, _: *CPSR, _: u32, _: u8) u32 {
    // @bitCast(u32, @bitCast(i32, r_val) >> @truncate(u5, amount))
    std.debug.panic("[BarrelShifter] implement arithmetic shift right", .{});
}

pub fn rotateRight(comptime S: bool, cpsr: *CPSR, rm: u32, amount: u8) u32 {
    const result = std.math.rotr(u32, rm, amount);

    if (S and result != 0) {
        cpsr.c.write(result >> 31 & 1 == 1);
    }

    return result;
}

pub fn rotateRightExtended(comptime S: bool, cpsr: *CPSR, rm: u32) u32 {
    if (!S) std.debug.panic("[BarrelShifter] Turns out I don't know how RRX works", .{});

    const carry: u32 = @boolToInt(cpsr.c.read());
    cpsr.c.write(rm & 1 == 1);

    return (carry << 31) | (rm >> 1);
}
