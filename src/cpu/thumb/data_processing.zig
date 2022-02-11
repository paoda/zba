const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;
const shifter = @import("../barrel_shifter.zig");

const add = @import("../arm/data_processing.zig").add;
const sub = @import("../arm/data_processing.zig").sub;
const cmp = @import("../arm/data_processing.zig").cmp;
const setLogicOpFlags = @import("../arm/data_processing.zig").setLogicOpFlags;

const log = std.log.scoped(.Thumb1);

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
                else => {
                    log.err("0b{b:0>2} is not a valid op", .{op});
                    // TODO: Should we panic here?
                },
            };

            // Equivalent to an ARM MOVS
            cpu.r[rd] = result;
            setLogicOpFlags(true, cpu, result);
        }
    }.inner;
}

pub fn format2(comptime I: bool, is_sub: bool, rn: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const rs = opcode >> 3 & 0x7;
            const rd = @truncate(u3, opcode);

            if (is_sub) {
                // SUB
                cpu.r[rd] = if (I) blk: {
                    break :blk sub(true, cpu, cpu.r[rs], rn);
                } else blk: {
                    break :blk sub(true, cpu, cpu.r[rs], cpu.r[rn]);
                };
            } else {
                // ADD
                cpu.r[rd] = if (I) blk: {
                    break :blk add(true, cpu, cpu.r[rs], rn);
                } else blk: {
                    break :blk add(true, cpu, cpu.r[rs], cpu.r[rn]);
                };
            }
        }
    }.inner;
}

pub fn format3(comptime op: u2, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const offset = @truncate(u8, opcode);

            switch (op) {
                0b00 => {
                    // MOV
                    cpu.r[rd] = offset;
                    setLogicOpFlags(true, cpu, offset);
                },
                0b01 => cmp(cpu, cpu.r[rd], offset), // CMP
                0b10 => cpu.r[rd] = add(true, cpu, cpu.r[rd], offset), // ADD
                0b11 => cpu.r[rd] = sub(true, cpu, cpu.r[rd], offset), // SUB
            }
        }
    }.inner;
}

pub fn format12(comptime isSP: bool, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // ADD
            const left = if (isSP) cpu.r[13] else (cpu.r[15] + 2) & 0xFFFF_FFFD;
            const right = (opcode & 0xFF) << 2;
            const result = left + right;
            cpu.r[rd] = result;
        }
    }.inner;
}

pub fn format13(comptime S: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // ADD
            const offset = (opcode & 0x7F) << 2;
            cpu.r[13] = if (S) cpu.r[13] - offset else cpu.r[13] + offset;
        }
    }.inner;
}
