const std = @import("std");
const util = @import("../../util.zig");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

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

            const modified_base = if (U) base + offset else base - offset;
            var address = if (P) modified_base else base;

            if (L) {
                switch (@truncate(u2, opcode >> 5)) {
                    0b00 => {
                        // SWP
                        const value = bus.read32(cpu.r[rn]);
                        const tmp = std.math.rotr(u32, value, 8 * (cpu.r[rn] & 0x3));
                        bus.write32(cpu.r[rm], tmp);
                    },
                    0b01 => {
                        // LDRH
                        const value = bus.read16(address & 0xFFFF_FFFE);
                        cpu.r[rd] = std.math.rotr(u32, @as(u32, value), 8 * (address & 1));
                    },
                    0b10 => {
                        // LDRSB
                        cpu.r[rd] = util.u32SignExtend(8, @as(u32, bus.read8(address)));
                        std.debug.panic("[CPU|ARM|LDRSB] TODO: Affect the CPSR", .{});
                    },
                    0b11 => {
                        // LDRSH
                        cpu.r[rd] = util.u32SignExtend(16, @as(u32, bus.read16(address)));
                        std.debug.panic("[CPU|ARM|LDRSH] TODO: Affect the CPSR", .{});
                    },
                }
            } else {
                if (opcode >> 5 & 0x01 == 0x01) {
                    // STRH
                    bus.write16(address, @truncate(u16, cpu.r[rd]));
                } else {
                    std.debug.print("[CPU|ARM|SignedDataTransfer] {X:0>8} was improperly decoded", .{opcode});
                }
            }

            address = modified_base;
            if (W and P or !P) cpu.r[rn] = address;
        }
    }.inner;
}
