const std = @import("std");

const BarrelShifter = @import("barrel_shifter.zig");
const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

pub fn dataProcessing(comptime I: bool, comptime S: bool, comptime instrKind: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            const rd = opcode >> 12 & 0xF;
            const rn = opcode >> 16 & 0xF;

            if (S and rd == 0xF) std.debug.panic("[CPU] Data Processing Instruction w/ S set and Rd == 15", .{});

            var op1: u32 = undefined;
            if (rn == 0xF) {
                op1 = cpu.fakePC();
            } else {
                op1 = cpu.r[rn];
            }

            var op2: u32 = undefined;
            if (I) {
                const amount = @truncate(u8, (opcode >> 8 & 0xF) << 1);
                op2 = BarrelShifter.rotateRight(S, &cpu.cpsr, opcode & 0xFF, amount);
            } else {
                op2 = BarrelShifter.exec(S, cpu, opcode);
            }

            switch (instrKind) {
                0x2 => {
                    // SUB
                    const result = op1 -% op2;
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        cpu.cpsr.c.write(op2 <= op1);
                        cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                    }
                },
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
                    const carry = @boolToInt(cpu.cpsr.c.read());
                    var result: u32 = undefined;

                    const did = @addWithOverflow(u32, op1, op2, &result);
                    const overflow = @addWithOverflow(u32, result, carry, &result);
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        cpu.cpsr.c.write(did or overflow);
                        cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
                    }
                },
                0x8 => {
                    // TST
                    const result = op1 & op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // Barrel Shifter should always calc CPSR C in TST
                    if (!S) _ = BarrelShifter.exec(true, cpu, opcode);
                },
                0x9 => {
                    // TEQ
                    const result = op1 ^ op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // Barrel Shifter should always calc CPSR C in TEQ
                    if (!S) _ = BarrelShifter.exec(true, cpu, opcode);
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
                0xA => {
                    // CMP
                    const result = op1 -% op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(op2 <= op1);
                    cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
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
                else => std.debug.panic("[CPU] TODO: implement data processing type {}", .{instrKind}),
            }
        }
    }.inner;
}
