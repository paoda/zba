const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

pub fn multiply(comptime A: bool, comptime S: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            const rd = opcode >> 16 & 0xF;
            const rn = opcode >> 12 & 0xF;
            const rs = opcode >> 8 & 0xF;
            const rm = opcode & 0xF;

            const result = cpu.r[rm] * cpu.r[rs] + if (A) cpu.r[rn] else 0;
            cpu.r[rd] = result;

            if (S) {
                cpu.cpsr.n.write(result >> 31 & 1 == 1);
                cpu.cpsr.z.write(result == 0);
                // V is unaffected, C is *actually* undefined in ARMv4
            }
        }
    }.inner;
}
