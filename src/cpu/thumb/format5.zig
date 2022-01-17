const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format5(comptime op: u2, comptime h1: u1, comptime h2: u1) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const src = @as(u4, h2) << 3 | (opcode >> 3 & 0x7);
            const dst = @as(u4, h1) << 3 | (opcode & 0x7);

            switch (op) {
                0b01 => {
                    // CMP
                    const left = cpu.r[dst];
                    const right = cpu.r[src];
                    const result = left -% right;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(right <= left);
                    cpu.cpsr.v.write(((left ^ result) & (~right ^ result)) >> 31 & 1 == 1);
                },
                0b10 => cpu.r[dst] = cpu.r[src], // MOV
                0b11 => {
                    // BX
                    cpu.cpsr.t.write(cpu.r[src] & 1 == 1);
                    cpu.r[15] = cpu.r[src] & 0xFFFF_FFFE;
                },
                else => std.debug.panic("[CPU] Op #{} is invalid for THUMB Format 5", .{op}),
            }
        }
    }.inner;
}
