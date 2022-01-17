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

    if (S) {
        return switch (@truncate(u2, opcode >> 5)) {
            0b00 => logicalLeft(&cpu.cpsr, value, shift_amt),
            0b01 => logicalRight(&cpu.cpsr, value, shift_amt),
            0b10 => arithmetic_right(&cpu.cpsr, value, shift_amt),
            0b11 => rotateRight(&cpu.cpsr, value, shift_amt),
        };
    } else {
        var dummy = CPSR{ .raw = 0x0000_0000 };
        return switch (@truncate(u2, opcode >> 5)) {
            0b00 => logicalLeft(&dummy, value, shift_amt),
            0b01 => logicalRight(&dummy, value, shift_amt),
            0b10 => arithmetic_right(&dummy, value, shift_amt),
            0b11 => rotateRight(&dummy, value, shift_amt),
        };
    }
}

pub fn logicalLeft(cpsr: *CPSR, rm: u32, shift_byte: u8) u32 {
    const shift_amt = @truncate(u5, shift_byte);
    const bit_count: u8 = @typeInfo(u32).Int.bits;

    var result: u32 = 0x0000_0000;

    if (shift_byte < bit_count) {
        // We can perform a well-defined shift here

        // FIXME: We assume cpu.r[rs] == 0 and imm_shift == 0 are equivalent
        if (shift_amt != 0) {
            const carry_bit = @truncate(u5, bit_count - shift_amt);
            cpsr.c.write(rm >> carry_bit & 1 == 1);
        }

        result = rm << shift_amt;
    } else if (shift_byte == bit_count) {
        // Shifted all bits out, carry bit is bit 0 of rm
        cpsr.c.write(rm & 1 == 1);
    } else {
        // Shifted all bits out, carry bit has also been shifted out
        cpsr.c.write(false);
    }

    return result;
}

pub fn logicalRight(cpsr: *CPSR, rm: u32, shift_byte: u8) u32 {
    const shift_amt = @truncate(u5, shift_byte);
    const bit_count: u8 = @typeInfo(u32).Int.bits;

    var result: u32 = 0x0000_0000;

    if (shift_byte == 0 or shift_byte == bit_count) {
        // Actualy LSR #32
        cpsr.c.write(rm >> 31 & 1 == 1);
    } else if (shift_byte < bit_count) {
        // We can perform a well-defined shift
        const carry_bit = shift_amt - 1;
        cpsr.c.write(rm >> carry_bit & 1 == 1);

        result = rm >> shift_amt;
    } else {
        // All bits have been shifted out, including carry bit
        cpsr.c.write(false);
    }

    return result;
}

pub fn arithmetic_right(_: *CPSR, _: u32, _: u8) u32 {
    // @bitCast(u32, @bitCast(i32, r_val) >> @truncate(u5, amount))
    std.debug.panic("[BarrelShifter] implement arithmetic shift right", .{});
}

pub fn rotateRight(cpsr: *CPSR, rm: u32, shift_byte: u8) u32 {
    const result = std.math.rotr(u32, rm, shift_byte);

    if (result != 0) {
        cpsr.c.write(result >> 31 & 1 == 1);
    }

    return result;
}
