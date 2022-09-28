const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").thumb.InstrFn;

const adc = @import("../arm/data_processing.zig").newAdc;
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

            var result: u32 = undefined;
            var didOverflow: bool = undefined;
            switch (op) {
                0x0 => result = cpu.r[rd] & cpu.r[rs], // AND
                0x1 => result = cpu.r[rd] ^ cpu.r[rs], // EOR
                0x2 => result = lsl(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs])), // LSL
                0x3 => result = lsr(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs])), // LSR
                0x4 => result = asr(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs])), // ASR
                0x5 => result = adc(&didOverflow, cpu.r[rd], cpu.r[rs], carry), // ADC
                0x6 => result = sbc(cpu.r[rd], cpu.r[rs], carry), // SBC
                0x7 => result = ror(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs])), // ROR
                0x8 => result = cpu.r[rd] & cpu.r[rs], // TST
                0x9 => result = 0 -% cpu.r[rs], // NEG
                0xA => result = cpu.r[rd] -% cpu.r[rs], // CMP
                0xB => didOverflow = @addWithOverflow(u32, cpu.r[rd], cpu.r[rs], &result), // CMN
                0xC => result = cpu.r[rd] | cpu.r[rs], // ORR
                0xD => result = @truncate(u32, @as(u64, cpu.r[rs]) * @as(u64, cpu.r[rd])),
                0xE => result = cpu.r[rd] & ~cpu.r[rs],
                0xF => result = ~cpu.r[rs],
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
                        cpu.cpsr.c.write(cpu.r[rs] <= cpu.r[rd]);
                        cpu.cpsr.v.write(((cpu.r[rd] ^ result) & (~cpu.r[rs] ^ result)) >> 31 & 1 == 1);
                    }
                },
                0x5, 0xB => {
                    // ADC, CMN
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(didOverflow);
                    cpu.cpsr.v.write(((cpu.r[rd] ^ result) & (cpu.r[rs] ^ result)) >> 31 & 1 == 1);

                    // FIXME: Pretty sure CMN Is the same
                },
                0x6 => {
                    // SBC
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);

                    const subtrahend = @as(u64, cpu.r[rs]) -% carry +% 1;
                    cpu.cpsr.c.write(subtrahend <= cpu.r[rd]);
                    cpu.cpsr.v.write(((cpu.r[rd] ^ result) & (~cpu.r[rs] ^ result)) >> 31 & 1 == 1);
                },
                0x9 => {
                    // NEG
                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(cpu.r[rs] <= 0);
                    cpu.cpsr.v.write(((0 ^ result) & (~cpu.r[rs] ^ result)) >> 31 & 1 == 1);
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
