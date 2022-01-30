const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;
const shifter = @import("../barrel_shifter.zig");

const adc = @import("../arm/data_processing.zig").adc;
const sbc = @import("../arm/data_processing.zig").sbc;
const sub = @import("../arm/data_processing.zig").sub;
const cmp = @import("../arm/data_processing.zig").cmp;
const cmn = @import("../arm/data_processing.zig").cmn;
const setTestOpFlags = @import("../arm/data_processing.zig").setTestOpFlags;
const setLogicOpFlags = @import("../arm/data_processing.zig").setLogicOpFlags;

pub fn format4(comptime op: u4) InstrFn {
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
                    const result = shifter.logicalLeft(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs]));
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x3 => {
                    // LSR
                    const result = shifter.logicalRight(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs]));
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x4 => {
                    // ASR
                    const result = shifter.arithmeticRight(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs]));
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
                    const result = shifter.rotateRight(true, &cpu.cpsr, cpu.r[rd], @truncate(u8, cpu.r[rs]));
                    cpu.r[rd] = result;
                    setLogicOpFlags(true, cpu, result);
                },
                0x8 => {
                    // TST
                    const result = cpu.r[rd] & cpu.r[rs];
                    setLogicOpFlags(true, cpu, result); // FIXME: Barrel Shifter?
                },
                0x9 => {
                    // NEG
                    cpu.r[rd] = sub(true, cpu, cpu.r[rs], cpu.r[rd]); // FIXME: I think this is wrong?
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
                    const result = cpu.r[rs] * cpu.r[rd];
                    cpu.r[rd] = result;
                    std.debug.panic("[CPU|THUMB|MUL] TODO: Set flags on ALU MUL", .{});
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
