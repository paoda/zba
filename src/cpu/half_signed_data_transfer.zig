const std = @import("std");
const util = @import("../util.zig");

const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const InstrFn = @import("../cpu.zig").InstrFn;

pub fn halfAndSignedDataTransfer(comptime P: bool, comptime U: bool, comptime I: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const rn = opcode >> 16 & 0xF;
            const rd = opcode >> 12 & 0xF;
            const rm = opcode & 0xF;
            const imm_offset_high = opcode >> 8 & 0xF;

            const base = cpu.r[rn];

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
                        std.debug.panic("[CPU] TODO: Implement SWP", .{});
                    },
                    0b01 => {
                        // LDRH
                        cpu.r[rd] = bus.read16(address);
                    },
                    0b10 => {
                        // LDRSB
                        cpu.r[rd] = util.u32SignExtend(8, @as(u32, bus.read8(address)));
                        std.debug.panic("TODO: Affect the CPSR", .{});
                    },
                    0b11 => {
                        // LDRSH
                        cpu.r[rd] = util.u32SignExtend(16, @as(u32, bus.read16(address)));
                        std.debug.panic("TODO: Affect the CPSR", .{});
                    },
                }
            } else {
                if (opcode >> 5 & 0x01 == 0x01) {
                    // STRH
                    bus.write16(address, @truncate(u16, cpu.r[rd]));
                } else {
                    std.debug.panic("[CPU] TODO: Figure out if this is also SWP", .{});
                }
            }

            address = modified_base;
            if (W and P or !P) cpu.r[rn] = address;
        }
    }.inner;
}
