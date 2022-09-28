const std = @import("std");
const util = @import("../../../util.zig");

const shifter = @import("../barrel_shifter.zig");
const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").arm.InstrFn;

const rotr = @import("../../../util.zig").rotr;

pub fn singleDataTransfer(comptime I: bool, comptime P: bool, comptime U: bool, comptime B: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const rn = opcode >> 16 & 0xF;
            const rd = opcode >> 12 & 0xF;

            // rn is r15 and L is not set, the PC is 12 ahead
            const base = cpu.r[rn] + if (!L and rn == 0xF) 4 else @as(u32, 0);

            const offset = if (I) shifter.immShift(false, cpu, opcode) else opcode & 0xFFF;

            const modified_base = if (U) base +% offset else base -% offset;
            var address = if (P) modified_base else base;

            var result: u32 = undefined;
            if (L) {
                if (B) {
                    // LDRB
                    result = bus.read(u8, address);
                } else {
                    // LDR
                    const value = bus.read(u32, address);
                    result = rotr(u32, value, 8 * (address & 0x3));
                }
            } else {
                if (B) {
                    // STRB
                    const value = cpu.r[rd] + if (rd == 0xF) 4 else @as(u32, 0); // PC is 12 ahead
                    bus.write(u8, address, @truncate(u8, value));
                } else {
                    // STR
                    const value = cpu.r[rd] + if (rd == 0xF) 4 else @as(u32, 0);
                    bus.write(u32, address, value);
                }
            }

            address = modified_base;
            if (W and P or !P) {
                cpu.r[rn] = address;
                if (rn == 0xF) cpu.pipe.reload(cpu);
            }

            if (L) {
                // This emulates the LDR rd == rn behaviour
                cpu.r[rd] = result;
                if (rd == 0xF) cpu.pipe.reload(cpu);
            }
        }
    }.inner;
}
