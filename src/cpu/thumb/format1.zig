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
                0b00 => blk: {
                    // LSL
                    if (offset == 0) {
                        break :blk cpu.r[rs];
                    } else {
                        break :blk shifter.logicalLeft(true, &cpu.cpsr, cpu.r[rs], offset);
                    }
                },
                0b01 => blk: {
                    // LSR
                    if (offset == 0) {
                        cpu.cpsr.c.write(cpu.r[rs] >> 31 & 1 == 1);
                        break :blk @as(u32, 0);
                    } else {
                        break :blk shifter.logicalRight(true, &cpu.cpsr, cpu.r[rs], offset);
                    }
                },
                0b10 => blk: {
                    // ASR
                    if (offset == 0) {
                        cpu.cpsr.c.write(cpu.r[rs] >> 31 & 1 == 1);
                        break :blk @bitCast(u32, @bitCast(i32, cpu.r[rs]) >> 31);
                    } else {
                        break :blk shifter.arithmeticRight(true, &cpu.cpsr, cpu.r[rs], offset);
                    }
                },
                else => cpu.panic("[CPU|THUMB|Fmt1] {} is an invalid op", .{op}),
            };

            // Equivalent to an ARM MOVS
            cpu.r[rd] = result;
            setLogicOpFlags(true, cpu, result);
        }
    }.inner;
}
