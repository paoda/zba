const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;
const u32SignExtend = @import("../../util.zig").u32SignExtend;

pub fn format19(comptime is_low: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // BL
            const offset = opcode & 0x3FF;

            if (is_low) {
                // Instruction 2
                const old_pc = cpu.r[15];

                cpu.r[15] = cpu.r[14] + (offset << 1);
                cpu.r[14] = old_pc | 1;
            } else {
                // Instruction 1
                cpu.r[14] = (cpu.r[15] + 2) + (u32SignExtend(11, @as(u32, offset)) << 12);
            }
        }
    }.inner;
}
