const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").thumb.InstrFn;

const add = @import("../arm/data_processing.zig").add;

const lsl = @import("../barrel_shifter.zig").lsl;
const lsr = @import("../barrel_shifter.zig").lsr;
const asr = @import("../barrel_shifter.zig").asr;

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
                        break :blk lsl(true, &cpu.cpsr, cpu.r[rs], offset);
                    }
                },
                0b01 => blk: {
                    // LSR
                    if (offset == 0) {
                        cpu.cpsr.c.write(cpu.r[rs] >> 31 & 1 == 1);
                        break :blk @as(u32, 0);
                    } else {
                        break :blk lsr(true, &cpu.cpsr, cpu.r[rs], offset);
                    }
                },
                0b10 => blk: {
                    // ASR
                    if (offset == 0) {
                        cpu.cpsr.c.write(cpu.r[rs] >> 31 & 1 == 1);
                        break :blk @bitCast(u32, @bitCast(i32, cpu.r[rs]) >> 31);
                    } else {
                        break :blk asr(true, &cpu.cpsr, cpu.r[rs], offset);
                    }
                },
                else => cpu.panic("[CPU/THUMB.1] 0b{b:0>2} is not a valid op", .{op}),
            };

            // Equivalent to an ARM MOVS
            cpu.r[rd] = result;

            // Write Flags
            cpu.cpsr.n.write(result >> 31 & 1 == 1);
            cpu.cpsr.z.write(result == 0);
        }
    }.inner;
}

pub fn fmt5(comptime op: u2, comptime h1: u1, comptime h2: u1) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const rs = @as(u4, h2) << 3 | (opcode >> 3 & 0x7);
            const rd = @as(u4, h1) << 3 | (opcode & 0x7);

            const op1 = cpu.r[rd];
            const op2 = cpu.r[rs];

            var result: u32 = undefined;
            var overflow: bool = undefined;
            switch (op) {
                0b00 => result = add(&overflow, op1, op2), // ADD
                0b01 => result = op1 -% op2, // CMP
                0b10 => result = op2, // MOV
                0b11 => {},
            }

            // Write to Destination Register
            switch (op) {
                0b01 => {}, // Test Instruction
                0b11 => {
                    // BX
                    const is_thumb = op2 & 1 == 1;
                    cpu.r[15] = op2 & ~@as(u32, 1);

                    cpu.cpsr.t.write(is_thumb);
                    cpu.pipe.reload(cpu);
                },
                else => {
                    cpu.r[rd] = result;
                    if (rd == 0xF) {
                        cpu.r[15] &= ~@as(u32, 1);
                        cpu.pipe.reload(cpu);
                    }
                },
            }

            // Write Flags
            switch (op) {
                0b01 => {
                    // CMP
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(op2 <= op1);
                    cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                },
                0b00, 0b10, 0b11 => {}, // MOV and Branch Instruction
            }
        }
    }.inner;
}

pub fn fmt2(comptime I: bool, is_sub: bool, rn: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const rs = opcode >> 3 & 0x7;
            const rd = @truncate(u3, opcode);
            const op1 = cpu.r[rs];
            const op2: u32 = if (I) rn else cpu.r[rn];

            if (is_sub) {
                // SUB
                const result = op1 -% op2;
                cpu.r[rd] = result;

                cpu.cpsr.n.write(result >> 31 & 1 == 1);
                cpu.cpsr.z.write(result == 0);
                cpu.cpsr.c.write(op2 <= op1);
                cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
            } else {
                // ADD
                var overflow: bool = undefined;
                const result = add(&overflow, op1, op2);
                cpu.r[rd] = result;

                cpu.cpsr.n.write(result >> 31 & 1 == 1);
                cpu.cpsr.z.write(result == 0);
                cpu.cpsr.c.write(overflow);
                cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
            }
        }
    }.inner;
}

pub fn fmt3(comptime op: u2, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const op1 = cpu.r[rd];
            const op2: u32 = opcode & 0xFF; // Offset

            var overflow: bool = undefined;
            const result: u32 = switch (op) {
                0b00 => op2, // MOV
                0b01 => op1 -% op2, // CMP
                0b10 => add(&overflow, op1, op2), // ADD
                0b11 => op1 -% op2, // SUB
            };

            // Write to Register
            if (op != 0b01) cpu.r[rd] = result;

            // Write Flags
            cpu.cpsr.n.write(result >> 31 & 1 == 1);
            cpu.cpsr.z.write(result == 0);

            switch (op) {
                0b00 => {}, // MOV | C set by Barrel Shifter, V is unaffected
                0b01, 0b11 => {
                    // SUB, CMP
                    cpu.cpsr.c.write(op2 <= op1);
                    cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                },
                0b10 => {
                    // ADD
                    cpu.cpsr.c.write(overflow);
                    cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
                },
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
