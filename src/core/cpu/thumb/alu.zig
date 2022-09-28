const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").thumb.InstrFn;

const adc = @import("../arm/data_processing.zig").adc;
const sbc = @import("../arm/data_processing.zig").sbc;

const lsl = @import("../barrel_shifter.zig").logicalLeft;
const lsr = @import("../barrel_shifter.zig").logicalRight;
const asr = @import("../barrel_shifter.zig").arithmeticRight;
const ror = @import("../barrel_shifter.zig").rotateRight;

pub fn fmt4(comptime op: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const rs = opcode >> 3 & 0x7;
            const rd = opcode & 0x7;
            const carry = @boolToInt(cpu.cpsr.c.read());

            const op1 = cpu.r[rd];
            const op2 = cpu.r[rs];

            var result: u32 = undefined;
            var overflow: bool = undefined;
            switch (op) {
                0x0 => result = op1 & op2, // AND
                0x1 => result = op1 ^ op2, // EOR
                0x2 => result = lsl(true, &cpu.cpsr, op1, @truncate(u8, op2)), // LSL
                0x3 => result = lsr(true, &cpu.cpsr, op1, @truncate(u8, op2)), // LSR
                0x4 => result = asr(true, &cpu.cpsr, op1, @truncate(u8, op2)), // ASR
                0x5 => result = adc(&overflow, op1, op2, carry), // ADC
                0x6 => result = sbc(op1, op2, carry), // SBC
                0x7 => result = ror(true, &cpu.cpsr, op1, @truncate(u8, op2)), // ROR
                0x8 => result = op1 & op2, // TST
                0x9 => result = 0 -% op2, // NEG
                0xA => result = op1 -% op2, // CMP
                0xB => overflow = @addWithOverflow(u32, op1, op2, &result), // CMN
                0xC => result = op1 | op2, // ORR
                0xD => result = @truncate(u32, @as(u64, op2) * @as(u64, op1)),
                0xE => result = op1 & ~op2,
                0xF => result = ~op2,
            }

            // Write to Destination Register
            switch (op) {
                0x8, 0xA, 0xB => {},
                else => cpu.r[rd] = result,
            }

            // Write Flags
            switch (op) {
                0x0, 0x1, 0x2, 0x3, 0x4, 0x7, 0xC, 0xE, 0xF => {
                    // Logic Operations
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // C set by Barrel Shifter, V is unaffected
                },
                0x8, 0xA => {
                    // Test Flags
                    // CMN (0xB) is handled with ADC
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);

                    if (op == 0xA) {
                        // CMP specific
                        cpu.cpsr.c.write(op2 <= op1);
                        cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                    }
                },
                0x5, 0xB => {
                    // ADC, CMN
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(overflow);
                    cpu.cpsr.v.write(((op1 ^ result) & (op2 ^ result)) >> 31 & 1 == 1);

                    // FIXME: Pretty sure CMN Is the same
                },
                0x6 => {
                    // SBC
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);

                    const subtrahend = @as(u64, op2) -% carry +% 1;
                    cpu.cpsr.c.write(subtrahend <= op1);
                    cpu.cpsr.v.write(((op1 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                },
                0x9 => {
                    // NEG
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(op2 <= 0);
                    cpu.cpsr.v.write(((0 ^ result) & (~op2 ^ result)) >> 31 & 1 == 1);
                },
                0xD => {
                    // Multiplication
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // V is unaffected, assuming similar behaviour to ARMv4 MUL C is undefined
                },
            }
        }
    }.inner;
}
