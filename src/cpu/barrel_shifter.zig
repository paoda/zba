const std = @import("std");

const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const CPSR = @import("../cpu.zig").PSR;

pub fn execute(comptime S: bool, cpu: *Arm7tdmi, opcode: u32) u32 {
    var result: u32 = undefined;
    if (opcode >> 4 & 1 == 1) {
        result = registerShift(S, cpu, opcode);
    } else {
        result = immShift(S, cpu, opcode);
    }

    return result;
}

fn registerShift(comptime S: bool, cpu: *Arm7tdmi, opcode: u32) u32 {
    const rs_idx = opcode >> 8 & 0xF;
    const rs = @truncate(u8, cpu.r[rs_idx]);

    const rm_idx = opcode & 0xF;
    const rm = if (rm_idx == 0xF) cpu.fakePC() else cpu.r[rm_idx];

    return switch (@truncate(u2, opcode >> 5)) {
        0b00 => logicalLeft(S, &cpu.cpsr, rm, rs),
        0b01 => logicalRight(S, &cpu.cpsr, rm, rs),
        0b10 => arithmeticRight(S, &cpu.cpsr, rm, rs),
        0b11 => rotateRight(S, &cpu.cpsr, rm, rs),
    };
}

fn immShift(comptime S: bool, cpu: *Arm7tdmi, opcode: u32) u32 {
    const amount = @truncate(u8, opcode >> 7 & 0x1F);

    const rm_idx = opcode & 0xF;
    const rm = if (rm_idx == 0xF) cpu.fakePC() else cpu.r[rm_idx];

    var result: u32 = undefined;
    if (amount == 0) {
        switch (@truncate(u2, opcode >> 5)) {
            0b00 => {
                // LSL #0
                result = rm;
            },
            0b01 => {
                // LSR #0 aka LSR #32
                if (S) cpu.cpsr.c.write(rm >> 31 & 1 == 1);
                result = 0x0000_0000;
            },
            0b10 => {
                // ASR #0 aka ASR #32
                result = @bitCast(u32, @bitCast(i32, rm) >> 31);
                if (S) cpu.cpsr.c.write(result >> 31 & 1 == 1);
            },
            0b11 => {
                // ROR #0 aka RRX
                const carry: u32 = @boolToInt(cpu.cpsr.c.read());
                if (S) cpu.cpsr.c.write(rm & 1 == 1);

                result = (carry << 31) | (rm >> 1);
            },
        }
    } else {
        switch (@truncate(u2, opcode >> 5)) {
            0b00 => result = logicalLeft(S, &cpu.cpsr, rm, amount),
            0b01 => result = logicalRight(S, &cpu.cpsr, rm, amount),
            0b10 => result = arithmeticRight(S, &cpu.cpsr, rm, amount),
            0b11 => result = rotateRight(S, &cpu.cpsr, rm, amount),
        }
    }

    return result;
}

pub fn logicalLeft(comptime S: bool, cpsr: *CPSR, rm: u32, total_amount: u8) u32 {
    const amount = @truncate(u5, total_amount);
    const bit_count: u8 = @typeInfo(u32).Int.bits;

    var result: u32 = 0x0000_0000;
    if (total_amount < bit_count) {
        // We can perform a well-defined shift here
        result = rm << amount;

        if (S and total_amount != 0) {
            const carry_bit = @truncate(u5, bit_count - amount);
            cpsr.c.write(rm >> carry_bit & 1 == 1);
        }
    } else {
        if (S) {
            if (total_amount == bit_count) {
                // Shifted all bits out, carry bit is bit 0 of rm
                cpsr.c.write(rm & 1 == 1);
            } else {
                cpsr.c.write(false);
            }
        }
    }

    return result;
}

pub fn logicalRight(comptime S: bool, cpsr: *CPSR, rm: u32, total_amount: u32) u32 {
    const amount = @truncate(u5, total_amount);
    const bit_count: u8 = @typeInfo(u32).Int.bits;

    var result: u32 = 0x0000_0000;
    if (total_amount < bit_count) {
        // We can perform a well-defined shift
        result = rm >> amount;
        if (S and total_amount != 0) cpsr.c.write(rm >> (amount - 1) & 1 == 1);
    } else {
        if (S) {
            if (total_amount == bit_count) {
                // LSR #32
                cpsr.c.write(rm >> 31 & 1 == 1);
            } else {
                // All bits have been shifted out, including carry bit
                cpsr.c.write(false);
            }
        }
    }

    return result;
}

pub fn arithmeticRight(comptime S: bool, cpsr: *CPSR, rm: u32, total_amount: u8) u32 {
    const amount = @truncate(u5, total_amount);
    const bit_count: u8 = @typeInfo(u32).Int.bits;

    var result: u32 = 0x0000_0000;
    if (total_amount < bit_count) {
        result = @bitCast(u32, @bitCast(i32, rm) >> amount);
        if (S and total_amount != 0) cpsr.c.write(rm >> (amount - 1) & 1 == 1);
    } else {
        if (S) {
            // ASR #32 and ASR #>32 have the same result
            result = @bitCast(u32, @bitCast(i32, rm) >> 31);
            cpsr.c.write(result >> 31 & 1 == 1);
        }
    }

    return result;
}

pub fn rotateRight(comptime S: bool, cpsr: *CPSR, rm: u32, total_amount: u8) u32 {
    const result = std.math.rotr(u32, rm, total_amount);

    if (S and total_amount != 0) {
        cpsr.c.write(result >> 31 & 1 == 1);
    }

    return result;
}
