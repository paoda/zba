const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;
const u32SignExtend = @import("../../util.zig").u32SignExtend;

pub fn format78(comptime op: u2, comptime T: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const ro = opcode >> 6 & 0x7;
            const rb = opcode >> 3 & 0x7;
            const rd = opcode & 0x7;

            const address = cpu.r[rb] + cpu.r[ro];

            if (T) {
                switch (op) {
                    0b00 => {
                        // STRH
                        bus.write16(address & 0xFFFF_FFFE, @truncate(u16, cpu.r[rd]));
                    },
                    0b01 => {
                        // LDRH
                        const value = bus.read16(address & 0xFFFF_FFFE);
                        cpu.r[rd] = std.math.rotr(u32, @as(u32, value), 8 * (address & 1));
                    },
                    0b10 => {
                        // LDSB
                        cpu.r[rd] = u32SignExtend(8, @as(u32, bus.read8(address)));
                    },
                    0b11 => {
                        // LDSH
                        cpu.r[rd] = u32SignExtend(16, @as(u32, bus.read16(address & 0xFFFF_FFFE)));
                    },
                }
            } else {
                switch (op) {
                    0b00 => {
                        // STR
                        bus.write32(address & 0xFFFF_FFFC, cpu.r[rd]);
                    },
                    0b01 => {
                        // STRB
                        bus.write8(address, @truncate(u8, cpu.r[rd]));
                    },
                    0b10 => {
                        // LDR
                        const value = bus.read32(address & 0xFFFF_FFFC);
                        cpu.r[rd] = std.math.rotr(u32, value, 8 * (address & 0x3));
                    },
                    0b11 => {
                        // LDRB
                        cpu.r[rd] = bus.read8(address);
                    },
                }
            }
        }
    }.inner;
}
