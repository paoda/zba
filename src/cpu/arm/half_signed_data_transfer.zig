const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

const sext = @import("../../util.zig").sext;

pub fn halfAndSignedDataTransfer(comptime P: bool, comptime U: bool, comptime I: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const rn = opcode >> 16 & 0xF;
            const rd = opcode >> 12 & 0xF;
            const rm = opcode & 0xF;
            const imm_offset_high = opcode >> 8 & 0xF;

            var base: u32 = undefined;
            if (rn == 0xF) {
                base = cpu.fakePC();
                if (!L) base += 4;
            } else {
                base = cpu.r[rn];
            }

            var offset: u32 = undefined;
            if (I) {
                offset = imm_offset_high << 4 | rm;
            } else {
                offset = cpu.r[rm];
            }

            const modified_base = if (U) base +% offset else base -% offset;
            var address = if (P) modified_base else base;

            var result: u32 = undefined;
            if (L) {
                switch (@truncate(u2, opcode >> 5)) {
                    0b01 => {
                        // LDRH
                        const value = bus.read16(address & 0xFFFF_FFFE);
                        result = std.math.rotr(u32, value, 8 * (address & 1));
                    },
                    0b10 => {
                        // LDRSB
                        result = sext(8, bus.read8(address));
                    },
                    0b11 => {
                        // LDRSH
                        const value = if (address & 1 == 1) blk: {
                            break :blk sext(8, bus.read8(address));
                        } else blk: {
                            break :blk sext(16, bus.read16(address));
                        };

                        result = std.math.rotr(u32, value, 8 * (address & 1));
                    },
                    0b00 => unreachable, // SWP
                }
            } else {
                if (opcode >> 5 & 0x01 == 0x01) {
                    // STRH
                    bus.write16(address & 0xFFFF_FFFE, @truncate(u16, cpu.r[rd]));
                } else unreachable; // SWP
            }

            address = modified_base;
            if (W and P or !P) cpu.r[rn] = address;
            if (L) cpu.r[rd] = result; // // This emulates the LDR rd == rn behaviour
        }
    }.inner;
}
