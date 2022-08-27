const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").thumb.InstrFn;
const shifter = @import("../barrel_shifter.zig");

const add = @import("../arm/data_processing.zig").add;
const sub = @import("../arm/data_processing.zig").sub;
const cmp = @import("../arm/data_processing.zig").cmp;
const setLogicOpFlags = @import("../arm/data_processing.zig").setLogicOpFlags;

pub fn fmt1(comptime op: u2, comptime offset: u5) InstrFn {
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
                else => cpu.panic("[CPU/THUMB.1] 0b{b:0>2} is not a valid op", .{op}),
            };

            // Equivalent to an ARM MOVS
            cpu.r[rd] = result;
            setLogicOpFlags(true, cpu, result);
        }
    }.inner;
}

pub fn fmt5(comptime op: u2, comptime h1: u1, comptime h2: u1) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const rs = @as(u4, h2) << 3 | (opcode >> 3 & 0x7);
            const rd = @as(u4, h1) << 3 | (opcode & 0x7);

            const rs_value = if (rs == 0xF) cpu.r[rs] & ~@as(u32, 1) else cpu.r[rs];
            const rd_value = if (rd == 0xF) cpu.r[rd] & ~@as(u32, 1) else cpu.r[rd];

            switch (op) {
                0b00 => {
                    // ADD
                    const sum = add(false, cpu, rd_value, rs_value);
                    cpu.r[rd] = if (rd == 0xF) sum & ~@as(u32, 1) else sum;
                },
                0b01 => cmp(cpu, rd_value, rs_value), // CMP
                0b10 => {
                    // MOV
                    cpu.r[rd] = if (rd == 0xF) rs_value & ~@as(u32, 1) else rs_value;
                },
                0b11 => {
                    // BX
                    const thumb = rs_value & 1 == 1;
                    cpu.r[15] = rs_value & ~@as(u32, 1);

                    cpu.cpsr.t.write(thumb);
                    if (thumb) cpu.pipe.reload(u16, cpu) else cpu.pipe.reload(u32, cpu);

                    // TODO: We shouldn't need to worry about the if statement
                    // below, because in BX, rd SBZ (and H1 is guaranteed to be 0)
                    return;
                },
            }

            if (rd == 0xF) cpu.pipe.reload(u16, cpu);
        }
    }.inner;
}

pub fn fmt2(comptime I: bool, is_sub: bool, rn: u3) InstrFn {
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

pub fn fmt3(comptime op: u2, comptime rd: u3) InstrFn {
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

pub fn fmt12(comptime isSP: bool, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // ADD
            const left = if (isSP) cpu.r[13] else cpu.r[15] & ~@as(u32, 2);
            const right = (opcode & 0xFF) << 2;
            cpu.r[rd] = left + right;
        }
    }.inner;
}

pub fn fmt13(comptime S: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // ADD
            const offset = (opcode & 0x7F) << 2;
            cpu.r[13] = if (S) cpu.r[13] - offset else cpu.r[13] + offset;
        }
    }.inner;
}
