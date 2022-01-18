const std = @import("std");

const shifter = @import("barrel_shifter.zig");
const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

pub fn dataProcessing(comptime I: bool, comptime S: bool, comptime instrKind: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            const rd = @truncate(u4, opcode >> 12 & 0xF);
            const rn = opcode >> 16 & 0xF;
            const old_carry = @boolToInt(cpu.cpsr.c.read());

            const op1 = if (rn == 0xF) cpu.fakePC() else cpu.r[rn];

            var op2: u32 = undefined;
            if (I) {
                const amount = @truncate(u8, (opcode >> 8 & 0xF) << 1);
                op2 = shifter.rotateRight(S, &cpu.cpsr, opcode & 0xFF, amount);
            } else {
                op2 = shifter.execute(S, cpu, opcode);
            }

            switch (instrKind) {
                0x0 => {
                    // AND
                    const result = op1 & op2;
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        // C set by Barrel Shifter, V is unaffected
                    }
                },
                0x1 => {
                    // EOR
                    const result = op1 ^ op2;
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        // C set by Barrel Shifter, V is unaffected
                    }
                },
                0x2 => sub(S, cpu, rd, op1, op2), // SUB
                0x3 => sub(S, cpu, rd, op2, op1), // RSB
                0x4 => {
                    // ADD
                    var result: u32 = undefined;
                    const didOverflow = @addWithOverflow(u32, op1, op2, &result);
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        cpu.cpsr.c.write(didOverflow);
                        cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
                    }
                },
                0x5 => {
                    // ADC
                    var result: u32 = undefined;

                    const did = @addWithOverflow(u32, op1, op2, &result);
                    const overflow = @addWithOverflow(u32, result, old_carry, &result);
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        cpu.cpsr.c.write(did or overflow);
                        cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
                    }
                },
                0x6 => sbc(S, cpu, rd, op1, op2, old_carry), // SBC
                0x7 => sbc(S, cpu, rd, op2, op1, old_carry), // RSC
                0x8 => {
                    // TST
                    const result = op1 & op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // Barrel Shifter should always calc CPSR C in TST
                    if (!S) _ = shifter.execute(true, cpu, opcode);
                },
                0x9 => {
                    // TEQ
                    const result = op1 ^ op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // Barrel Shifter should always calc CPSR C in TEQ
                    if (!S) _ = shifter.execute(true, cpu, opcode);
                },
                0xA => {
                    // CMP
                    const result = op1 -% op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(op2 <= op1);
                    cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                },
                0xB => {
                    // CMN
                    var result: u32 = undefined;
                    const didOverflow = @addWithOverflow(u32, op1, op2, &result);

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(didOverflow);
                    cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
                },
                0xC => {
                    // ORR
                    const result = op1 | op2;
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        // C set by Barrel Shifter, V is unaffected
                    }
                },
                0xD => {
                    // MOV
                    cpu.r[rd] = op2;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(op2 >> 31 & 1 == 1);
                        cpu.cpsr.z.write(op2 == 0);
                        // C set by Barrel Shifter, V is unaffected
                    }
                },
                0xE => {
                    // BIC
                    const result = op1 & ~op2;
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        // C set by Barrel Shifter, V is unaffected
                    }
                },
                0xF => {
                    // MVN
                    const result = ~op2;
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        // C set by Barrel Shifter, V is unaffected
                    }
                },
            }
        }
    }.inner;
}

fn sbc(comptime S: bool, cpu: *Arm7tdmi, rd: u4, left: u32, right: u32, old_carry: u1) void {
    // TODO: Make your own version (thanks peach.bot)
    const subtrahend = @as(u64, right) - old_carry + 1;
    const result = @truncate(u32, left -% subtrahend);
    cpu.r[rd] = result;

    if (S and rd != 0xF) {
        cpu.cpsr.n.write(result >> 31 & 1 == 1);
        cpu.cpsr.z.write(result == 0);
        cpu.cpsr.c.write(subtrahend <= left);
        cpu.cpsr.v.write(((left ^ result) & (~right ^ result)) >> 31 & 1 == 1);
    }
}

fn sub(comptime S: bool, cpu: *Arm7tdmi, rd: u4, left: u32, right: u32) void {
    const result = left -% right;
    cpu.r[rd] = result;

    if (S and rd != 0xF) {
        cpu.cpsr.n.write(result >> 31 & 1 == 1);
        cpu.cpsr.z.write(result == 0);
        cpu.cpsr.c.write(right <= left);
        cpu.cpsr.v.write(((left ^ result) & (~right ^ result)) >> 31 & 1 == 1);
    }
}
