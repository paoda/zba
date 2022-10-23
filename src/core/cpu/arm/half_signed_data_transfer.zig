const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").arm.InstrFn;

const sext = @import("../../../util.zig").sext;
const rotr = @import("../../../util.zig").rotr;

pub fn halfAndSignedDataTransfer(comptime P: bool, comptime U: bool, comptime I: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const rn = opcode >> 16 & 0xF;
            const rd = opcode >> 12 & 0xF;
            const rm = opcode & 0xF;
            const imm_offset_high = opcode >> 8 & 0xF;

            const base = cpu.r[rn] + if (!L and rn == 0xF) 4 else @as(u32, 0);
            const offset = if (I) imm_offset_high << 4 | rm else cpu.r[rm];

            const modified_base = if (U) base +% offset else base -% offset;
            var address = if (P) modified_base else base;

            var result: u32 = undefined;
            if (L) {
                switch (@truncate(u2, opcode >> 5)) {
                    0b01 => {
                        // LDRH
                        const value = bus.read(u16, address);
                        result = rotr(u32, value, 8 * (address & 1));
                    },
                    0b10 => {
                        // LDRSB
                        result = sext(u32, u8, bus.read(u8, address));
                    },
                    0b11 => {
                        // LDRSH
                        const value = bus.read(u16, address);
                        result = if (address & 1 == 1) sext(u32, u8, @truncate(u8, value >> 8)) else sext(u32, u16, value);
                    },
                    0b00 => unreachable, // SWP
                }
            } else {
                if (opcode >> 5 & 0x01 == 0x01) {
                    // STRH
                    bus.write(u16, address, @truncate(u16, cpu.r[rd]));
                } else unreachable; // SWP
            }

            address = modified_base;
            if (W and P or !P) cpu.r[rn] = address;
            if (L) cpu.r[rd] = result; // // This emulates the LDR rd == rn behaviour
        }
    }.inner;
}
