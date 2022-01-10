const std = @import("std");

const BarrelShifter = @import("barrel_shifter.zig");
const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const InstrFn = @import("../cpu.zig").InstrFn;

pub fn dataProcessing(comptime I: bool, comptime S: bool, comptime instrKind: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            const rd = opcode >> 12 & 0xF;
            const op1 = opcode >> 16 & 0xF;

            var op2: u32 = undefined;
            if (I) {
                op2 = std.math.rotr(u32, opcode & 0xFF, (opcode >> 8 & 0xF) << 1);
            } else {
                if (S and rd == 0xF) {
                    std.debug.panic("[CPU] Data Processing Instruction w/ S set and Rd == 15", .{});
                } else {
                    op2 = BarrelShifter.exec(S, cpu, opcode);
                }
            }

            switch (instrKind) {
                0x4 => {
                    // ADD
                    var result: u32 = undefined;
                    const didOverflow = @addWithOverflow(u32, cpu.r[op1], op2, &result);
                    cpu.r[rd] = result;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        cpu.cpsr.c.write(didOverflow);
                        cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
                    }
                },
                0x8 => {
                    // TST
                    const result = cpu.r[op1] & op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // Barrel Shifter should always calc CPSR C in TST
                    if (!S) _ = BarrelShifter.exec(true, cpu, opcode);
                },
                0xD => {
                    // MOV
                    cpu.r[rd] = op2;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(op2 >> 31 & 1 == 1);
                        cpu.cpsr.z.write(op2 == 0);
                        // C set by Barr0x15el Shifter, V is unnafected
                    }
                },
                0xA => {
                    // CMP
                    const result = cpu.r[op1] -% op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(op2 <= cpu.r[op1]);
                    cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                },
                0xC => {
                    // ORR
                    const result = cpu.r[op1] | op2;

                    if (S and rd != 0xF) {
                        cpu.cpsr.n.write(result >> 31 & 1 == 1);
                        cpu.cpsr.z.write(result == 0);
                        // C set by Barr0x15el Shifter, V is unnafected
                    }
                },
                else => std.debug.panic("[CPU] TODO: implement data processing type {}", .{instrKind}),
            }
        }
    }.inner;
}
