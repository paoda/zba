const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").thumb.InstrFn;

const adc = @import("../arm/data_processing.zig").adc;
const sbc = @import("../arm/data_processing.zig").sbc;
const sub = @import("../arm/data_processing.zig").sub;
const cmp = @import("../arm/data_processing.zig").cmp;
const cmn = @import("../arm/data_processing.zig").cmn;
const setTestOpFlags = @import("../arm/data_processing.zig").setTestOpFlags;
const setLogicOpFlags = @import("../arm/data_processing.zig").setLogicOpFlags;

const logicalLeft = @import("../barrel_shifter.zig").logicalLeft;
const logicalRight = @import("../barrel_shifter.zig").logicalRight;
const arithmeticRight = @import("../barrel_shifter.zig").arithmeticRight;
const rotateRight = @import("../barrel_shifter.zig").rotateRight;

pub fn fmt4(comptime op: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const rs = opcode >> 3 & 0x7;
            const rd = opcode & 0x7;
            const carry = @boolToInt(cpu.cpsr.c.read());

            switch (op) {
                0x0 => {
                    // AND
                    const result = cpu.r[rd] & cpu.r[rs];
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x1 => {
                    // EOR
                    const result = cpu.r[rd] ^ cpu.r[rs];
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x2 => {
                    // LSL
                    const result = logicalLeft(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs]));
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x3 => {
                    // LSR
                    const result = logicalRight(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs]));
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x4 => {
                    // ASR
                    const result = arithmeticRight(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs]));
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x5 => {
                    // ADC
                    cpu.r[rd] = adc(true, cpu, cpu.r[rd], cpu.r[rs], carry);
                },
                0x6 => {
                    // SBC
                    cpu.r[rd] = sbc(true, cpu, cpu.r[rd], cpu.r[rs], carry);
                },
                0x7 => {
                    // ROR
                    const result = rotateRight(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs]));
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x8 => {
                    // TST
                    const result = cpu.r[rd] & cpu.r[rs];
                    setLogicOpFlags(true, cpu, result);
                },
                0x9 => {
                    // NEG
                    cpu.r[rd] = sub(true, cpu, 0, cpu.r[rs]);
                },
                0xA => {
                    // CMP
                    cmp(cpu, cpu.r[rd], cpu.r[rs]);
                },
                0xB => {
                    // CMN
                    cmn(cpu, cpu.r[rd], cpu.r[rs]);
                },
                0xC => {
                    // ORR
                    const result = cpu.r[rd] | cpu.r[rs];
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0xD => {
                    // MUL
                    const temp = @as(u64, cpu.r[rs]) * @as(u64, cpu.r[rd]);
                    const result = @truncate(u32, temp);
                    cpu.r[rd] = result;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    // V is unaffected, assuming similar behaviour to ARMv4 MUL C is undefined
                },
                0xE => {
                    // BIC
                    const result = cpu.r[rd] & ~cpu.r[rs];
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0xF => {
                    // MVN
                    const result = ~cpu.r[rs];
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
            }
        }
    }.inner;
}
