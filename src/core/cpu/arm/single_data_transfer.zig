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

            var base: u32 = undefined;
            if (rn == 0xF) {
                base = cpu.fakePC();
                if (!L) base += 4; // Offset of 12
            } else {
                base = cpu.r[rn];
            }

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
                    const value = if (rd == 0xF) cpu.r[rd] + 8 else cpu.r[rd];
                    bus.write(u8, address, @truncate(u8, value));
                } else {
                    // STR
                    const value = if (rd == 0xF) cpu.r[rd] + 8 else cpu.r[rd];
                    bus.write(u32, address, value);
                }
            }

            address = modified_base;
            if (W and P or !P) cpu.r[rn] = address;
            if (L) cpu.r[rd] = result; // This emulates the LDR rd == rn behaviour
        }
    }.inner;
}
