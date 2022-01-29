const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

const add = @import("../arm/data_processing.zig").add;
const sub = @import("../arm/data_processing.zig").sub;

pub fn format2(comptime I: bool, is_sub: bool, rn: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const rs = opcode >> 3 & 0x7;
            const rd = @truncate(u3, opcode);

            if (is_sub) {
                // SUB
                cpu.r[rd] = if (I) blk: {
                    break :blk sub(true, cpu, rd, cpu.r[rs], @as(u32, rn));
                } else blk: {
                    break :blk sub(true, cpu, rd, cpu.r[rs], cpu.r[rn]);
                };
            } else {
                // ADD
                cpu.r[rd] = if (I) blk: {
                    break :blk add(true, cpu, rd, cpu.r[rs], @as(u32, rn));
                } else blk: {
                    break :blk add(true, cpu, rd, cpu.r[rs], cpu.r[rn]);
                };
            }
        }
    }.inner;
}
