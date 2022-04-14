const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

const rotr = @import("../../util.zig").rotr;

pub fn format6(comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            // LDR
            const offset = (opcode & 0xFF) << 2;
            cpu.r[rd] = bus.read(u32, (cpu.r[15] + 2 & 0xFFFF_FFFD) + offset);
        }
    }.inner;
}

const sext = @import("../../util.zig").sext;

pub fn format78(comptime op: u2, comptime T: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const ro = opcode >> 6 & 0x7;
            const rb = opcode >> 3 & 0x7;
            const rd = opcode & 0x7;

            const address = cpu.r[rb] + cpu.r[ro];

            if (T) {
                // Format 8
                switch (op) {
                    0b00 => {
                        // STRH
                        bus.write(u16, address, @truncate(u16, cpu.r[rd]));
                    },
                    0b01 => {
                        // LDSB
                        cpu.r[rd] = sext(8, bus.read(u8, address));
                    },
                    0b10 => {
                        // LDRH
                        const value = bus.read(u16, address);
                        cpu.r[rd] = rotr(u32, value, 8 * (address & 1));
                    },
                    0b11 => {
                        // LDRSH
                        cpu.r[rd] = if (address & 1 == 1) blk: {
                            break :blk sext(8, bus.read(u8, address));
                        } else blk: {
                            break :blk sext(16, bus.read(u16, address));
                        };
                    },
                }
            } else {
                // Format 7
                switch (op) {
                    0b00 => {
                        // STR
                        bus.write(u32, address, cpu.r[rd]);
                    },
                    0b01 => {
                        // STRB
                        bus.write(u8, address, @truncate(u8, cpu.r[rd]));
                    },
                    0b10 => {
                        // LDR
                        const value = bus.read(u32, address);
                        cpu.r[rd] = rotr(u32, value, 8 * (address & 0x3));
                    },
                    0b11 => {
                        // LDRB
                        cpu.r[rd] = bus.read(u8, address);
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
                    cpu.r[rd] = bus.read(u8, address);
                } else {
                    // LDR
                    const address = cpu.r[rb] + (@as(u32, offset) << 2);
                    const value = bus.read(u32, address);
                    cpu.r[rd] = rotr(u32, value, 8 * (address & 0x3));
                }
            } else {
                if (B) {
                    // STRB
                    const address = cpu.r[rb] + offset;
                    bus.write(u8, address, @truncate(u8, cpu.r[rd]));
                } else {
                    // STR
                    const address = cpu.r[rb] + (@as(u32, offset) << 2);
                    bus.write(u32, address, cpu.r[rd]);
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

            const address = cpu.r[rb] + (@as(u6, offset) << 1);

            if (L) {
                // LDRH
                const value = bus.read(u16, address);
                cpu.r[rd] = rotr(u32, value, 8 * (address & 1));
            } else {
                // STRH
                bus.write(u16, address, @truncate(u16, cpu.r[rd]));
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
                const value = bus.read(u32, address);
                cpu.r[rd] = rotr(u32, value, 8 * (address & 0x3));
            } else {
                // STR
                bus.write(u32, address, cpu.r[rd]);
            }
        }
    }.inner;
}
