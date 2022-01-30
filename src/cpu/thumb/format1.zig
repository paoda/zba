const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;
const shifter = @import("../barrel_shifter.zig");

const setLogicOpFlags = @import("../arm/data_processing.zig").setLogicOpFlags;

pub fn format1(comptime op: u2, comptime offset: u5) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const rs = opcode >> 3 & 0x7;
            const rd = opcode & 0x7;

            const result = switch (op) {
                0b00 => shifter.logicalLeft(true, &cpu.cpsr, cpu.r[rs], offset), // LSL
                0b01 => shifter.logicalRight(true, &cpu.cpsr, cpu.r[rs], offset), // LSR
                0b10 => shifter.arithmeticRight(true, &cpu.cpsr, cpu.r[rs], offset), // ASR
                else => std.debug.panic("[CPU|THUMB|Fmt1] {} is an invalid op", .{op}),
            };

            // Equivalent to an ARM MOVS
            cpu.r[rd] = result;
            setLogicOpFlags(true, cpu, result);
        }
    }.inner;
}
