const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const CPSR = @import("../cpu.zig").PSR;

const rotr = @import("zba-util").rotr;

pub fn exec(comptime S: bool, cpu: *Arm7tdmi, opcode: u32) u32 {
    var result: u32 = undefined;
    if (opcode >> 4 & 1 == 1) {
        result = register(S, cpu, opcode);
    } else {
        result = immediate(S, cpu, opcode);
    }

    return result;
}

fn register(comptime S: bool, cpu: *Arm7tdmi, opcode: u32) u32 {
    const rs_idx = opcode >> 8 & 0xF;
    const rm = cpu.r[opcode & 0xF];
    const rs = @truncate(u8, cpu.r[rs_idx]);

    return switch (@truncate(u2, opcode >> 5)) {
        0b00 => lsl(S, &cpu.cpsr, rm, rs),
        0b01 => lsr(S, &cpu.cpsr, rm, rs),
        0b10 => asr(S, &cpu.cpsr, rm, rs),
        0b11 => ror(S, &cpu.cpsr, rm, rs),
    };
}

pub fn immediate(comptime S: bool, cpu: *Arm7tdmi, opcode: u32) u32 {
    const amount = @truncate(u8, opcode >> 7 & 0x1F);
    const rm = cpu.r[opcode & 0xF];

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
            0b00 => result = lsl(S, &cpu.cpsr, rm, amount),
            0b01 => result = lsr(S, &cpu.cpsr, rm, amount),
            0b10 => result = asr(S, &cpu.cpsr, rm, amount),
            0b11 => result = ror(S, &cpu.cpsr, rm, amount),
        }
    }

    return result;
}

pub fn lsl(comptime S: bool, cpsr: *CPSR, rm: u32, total_amount: u8) u32 {
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

pub fn lsr(comptime S: bool, cpsr: *CPSR, rm: u32, total_amount: u32) u32 {
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

pub fn asr(comptime S: bool, cpsr: *CPSR, rm: u32, total_amount: u8) u32 {
    const amount = @truncate(u5, total_amount);
    const bit_count: u8 = @typeInfo(u32).Int.bits;

    var result: u32 = 0x0000_0000;
    if (total_amount < bit_count) {
        result = @bitCast(u32, @bitCast(i32, rm) >> amount);
        if (S and total_amount != 0) cpsr.c.write(rm >> (amount - 1) & 1 == 1);
    } else {
        // ASR #32 and ASR #>32 have the same result
        result = @bitCast(u32, @bitCast(i32, rm) >> 31);
        if (S) cpsr.c.write(result >> 31 & 1 == 1);
    }

    return result;
}

pub fn ror(comptime S: bool, cpsr: *CPSR, rm: u32, total_amount: u8) u32 {
    const result = rotr(u32, rm, total_amount);

    if (S and total_amount != 0) {
        cpsr.c.write(result >> 31 & 1 == 1);
    }

    return result;
}
