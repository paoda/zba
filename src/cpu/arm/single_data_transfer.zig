const std = @import("std");
const util = @import("../../util.zig");

const BarrelShifter = @import("barrel_shifter.zig");
const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const CPSR = @import("../../cpu.zig").PSR;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

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

            const offset = if (I) registerOffset(cpu, opcode) else opcode & 0xFFF;

            const modified_base = if (U) base + offset else base - offset;
            var address = if (P) modified_base else base;

            if (L) {
                if (B) {
                    // LDRB
                    cpu.r[rd] = bus.read8(address);
                } else {
                    // LDR
                    const value = bus.read32(address & 0xFFFF_FFFC);
                    cpu.r[rd] = std.math.rotr(u32, value, 8 * (address & 0x3));
                }
            } else {
                if (B) {
                    // STRB
                    bus.write8(address, @truncate(u8, cpu.r[rd]));
                } else {
                    // STR
                    const force_aligned = address & 0xFFFF_FFFC;
                    bus.write32(force_aligned, cpu.r[rd]);
                }
            }

            address = modified_base;
            if (W and P or !P) cpu.r[rn] = address;

            // TODO: W-bit forces non-privledged mode for the transfer
        }
    }.inner;
}

fn registerOffset(cpu: *Arm7tdmi, opcode: u32) u32 {
    const shift_byte = @truncate(u8, opcode >> 7 & 0x1F);

    const rm = cpu.r[opcode & 0xF];

    var dummy = CPSR{ .raw = 0x0000_0000 };

    return switch (@truncate(u2, opcode >> 5)) {
        0b00 => BarrelShifter.logical_left(&dummy, rm, shift_byte),
        0b01 => BarrelShifter.logical_right(&dummy, rm, shift_byte),
        0b10 => BarrelShifter.arithmetic_right(&dummy, rm, shift_byte),
        0b11 => BarrelShifter.rotate_right(&dummy, rm, shift_byte),
    };
}
