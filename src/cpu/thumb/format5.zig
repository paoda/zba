const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

const cmp = @import("../arm/data_processing.zig").cmp;

pub fn format5(comptime op: u2, comptime h1: u1, comptime h2: u1) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const src = @as(u4, h2) << 3 | (opcode >> 3 & 0x7);
            const dst = @as(u4, h1) << 3 | (opcode & 0x7);

            switch (op) {
                0b01 => cmp(cpu, cpu.r[dst], cpu.r[src]), // CMP
                0b10 => cpu.r[dst] = cpu.r[src], // MOV
                0b11 => {
                    // BX
                    cpu.cpsr.t.write(cpu.r[src] & 1 == 1);
                    cpu.r[15] = cpu.r[src] & 0xFFFF_FFFE;
                },
                else => std.debug.panic("[CPU|THUMB|Fmt5] {} is an invalid op", .{op}),
            }
        }
    }.inner;
}
