const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").arm.InstrFn;

const rotateRight = @import("../barrel_shifter.zig").rotateRight;
const execute = @import("../barrel_shifter.zig").execute;

pub fn dataProcessing(comptime I: bool, comptime S: bool, comptime kind: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            const rd = @truncate(u4, opcode >> 12 & 0xF);
            const rn = opcode >> 16 & 0xF;
            const old_carry = @boolToInt(cpu.cpsr.c.read());

            // If certain conditions are met, PC is 12 ahead instead of 8
            // TODO: Why these conditions?
            if (!I and opcode >> 4 & 1 == 1) cpu.r[15] += 4;
            const op1 = cpu.r[rn];

            const amount = @truncate(u8, (opcode >> 8 & 0xF) << 1);
            const op2 = if (I) rotateRight(S, &cpu.cpsr, opcode & 0xFF, amount) else execute(S, cpu, opcode);

            // Undo special condition from above
            if (!I and opcode >> 4 & 1 == 1) cpu.r[15] -= 4;

            var result: u32 = undefined;
            var overflow: bool = undefined;

            // Perform Data Processing Logic
            switch (kind) {
                0x0 => result = op1 & op2, // AND
                0x1 => result = op1 ^ op2, // EOR
                0x2 => result = op1 -% op2, // SUB
                0x3 => result = op2 -% op1, // RSB
                0x4 => result = add(&overflow, op1, op2), // ADD
                0x5 => result = adc(&overflow, op1, op2, old_carry), // ADC
                0x6 => result = sbc(op1, op2, old_carry), // SBC
                0x7 => result = sbc(op2, op1, old_carry), // RSC
                0x8 => {
                    // TST
                    if (rd == 0xF)
                        return undefinedTestBehaviour(cpu);

                    result = op1 & op2;
                },
                0x9 => {
                    // TEQ
                    if (rd == 0xF)
                        return undefinedTestBehaviour(cpu);

                    result = op1 ^ op2;
                },
                0xA => {
                    // CMP
                    if (rd == 0xF)
                        return undefinedTestBehaviour(cpu);

                    result = op1 -% op2;
                },
                0xB => {
                    // CMN
                    if (rd == 0xF)
                        return undefinedTestBehaviour(cpu);

                    overflow = @addWithOverflow(u32, op1, op2, &result);
                },
                0xC => result = op1 | op2, // ORR
                0xD => result = op2, // MOV
                0xE => result = op1 & ~op2, // BIC
                0xF => result = ~op2, // MVN
            }

            // Write to Destination Register
            switch (kind) {
                0x8, 0x9, 0xA, 0xB => {}, // Test Operations
                else => {
                    cpu.r[rd] = result;
                    if (rd == 0xF) {
                        if (S) cpu.setCpsrNoFlush(cpu.spsr.raw);

                        cpu.pipe.reload(u32, cpu);
                    }
                },
            }

            // Write Flags
            switch (kind) {
                0x0, 0x1, 0xC, 0xD, 0xE, 0xF => if (S and rd != 0xF) {
                    // Logic Operation Flags
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // C set by Barrel Shifter, V is unaffected

                },
                0x2, 0x3 => if (S and rd != 0xF) {
                    // SUB, RSB Flags
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);

                    if (kind == 0x2) {
                        // SUB specific
                        cpu.cpsr.c.write(op2 <= op1);
                        cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                    } else {
                        // RSB Specific
                        cpu.cpsr.c.write(op1 <= op2);
                        cpu.cpsr.v.write(((op2 ^ result) & (~op1 ^ result)) >> 31 & 1 == 1);
                    }
                },
                0x4, 0x5 => if (S and rd != 0xF) {
                    // ADD, ADC Flags
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(overflow);
                    cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
                },
                0x6, 0x7 => if (S and rd != 0xF) {
                    // SBC, RSC Flags
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);

                    if (kind == 0x6) {
                        // SBC specific
                        const subtrahend = @as(u64, op2) -% old_carry +% 1;
                        cpu.cpsr.c.write(subtrahend <= op1);
                        cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                    } else {
                        // RSC Specific
                        const subtrahend = @as(u64, op1) -% old_carry +% 1;
                        cpu.cpsr.c.write(subtrahend <= op2);
                        cpu.cpsr.v.write(((op2 ^ result) & (~op1 ^ result)) >> 31 & 1 == 1);
                    }
                },
                0x8, 0x9, 0xA, 0xB => {
                    // Test Operation Flags
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);

                    if (kind == 0xA) {
                        // CMP specific
                        cpu.cpsr.c.write(op2 <= op1);
                        cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                    } else if (kind == 0xB) {
                        // CMN specific
                        cpu.cpsr.c.write(overflow);
                        cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);
                    } else {
                        // TST, TEQ specific
                        // Barrel Shifter should always calc CPSR C in TST
                        if (!S) _ = execute(true, cpu, opcode);
                    }
                },
            }
        }
    }.inner;
}

pub fn sbc(left: u32, right: u32, old_carry: u1) u32 {
    // TODO: Make your own version (thanks peach.bot)
    const subtrahend = @as(u64, right) -% old_carry +% 1;
    const ret = @truncate(u32, left -% subtrahend);

    return ret;
}

pub fn add(overflow: *bool, left: u32, right: u32) u32 {
    var ret: u32 = undefined;
    overflow.* = @addWithOverflow(u32, left, right, &ret);
    return ret;
}

pub fn adc(overflow: *bool, left: u32, right: u32, old_carry: u1) u32 {
    var ret: u32 = undefined;
    const first = @addWithOverflow(u32, left, right, &ret);
    const second = @addWithOverflow(u32, ret, old_carry, &ret);

    overflow.* = first or second;
    return ret;
}

fn undefinedTestBehaviour(cpu: *Arm7tdmi) void {
    @setCold(true);
    cpu.setCpsrNoFlush(cpu.spsr.raw);
}
