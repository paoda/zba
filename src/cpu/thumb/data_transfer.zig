const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format6(comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            // LDR
            const offset = (opcode & 0xFF) << 2;

            // FIXME: Should this overflow?
            cpu.r[rd] = bus.read32((cpu.r[15] + 2 & 0xFFFF_FFFD) + offset);
        }
    }.inner;
}

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

pub fn format9(comptime B: bool, comptime L: bool, comptime offset: u5) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const rb = opcode >> 3 & 0x7;
            const rd = opcode & 0x7;

            if (L) {
                if (B) {
                    // LDRB
                    const address = cpu.r[rb] + offset;
                    cpu.r[rd] = bus.read8(address);
                } else {
                    // LDR
                    const address = cpu.r[rb] + (@as(u32, offset) << 2);
                    const value = bus.read32(address & 0xFFFF_FFFC);
                    cpu.r[rd] = std.math.rotr(u32, value, 8 * (address & 0x3));
                }
            } else {
                if (B) {
                    // STRB
                    const address = cpu.r[rb] + offset;
                    bus.write8(address, @truncate(u8, cpu.r[rd]));
                } else {
                    // STR
                    const address = cpu.r[rb] + (@as(u32, offset) << 2);
                    bus.write32(address & 0xFFFF_FFFC, cpu.r[rd]);
                }
            }
        }
    }.inner;
}

pub fn format10(comptime L: bool, comptime offset: u5) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const rb = opcode >> 3 & 0x7;
            const rd = opcode & 0x7;

            const address = cpu.r[rb] + (offset << 1);

            if (L) {
                // LDRH
                const value = bus.read16(address & 0xFFFF_FFFE);
                cpu.r[rd] = std.math.rotr(u32, @as(u32, value), 8 * (address & 1));
            } else {
                // STRH
                bus.write16(address & 0xFFFF_FFFE, @truncate(u16, cpu.r[rd]));
            }
        }
    }.inner;
}

pub fn format11(comptime L: bool, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const offset = (opcode & 0xFF) << 2;
            const address = cpu.r[13] + offset;

            if (L) {
                // LDR
                const value = bus.read32(address & 0xFFFF_FFFC);
                cpu.r[rd] = std.math.rotr(u32, value, 8 * (address & 0x3));
            } else {
                // STR
                bus.write32(address & 0xFFFF_FFFC, cpu.r[rd]);
            }
        }
    }.inner;
}
