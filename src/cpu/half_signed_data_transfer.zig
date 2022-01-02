const std = @import("std");
const processor = @import("../cpu.zig");
const util = @import("../util.zig");

const Bus = @import("../bus.zig").Bus;
const Arm7tdmi = processor.Arm7tdmi;
const InstrFn = processor.InstrFn;

pub fn comptimeHalfSignedDataTransfer(comptime P: bool, comptime U: bool, comptime I: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn halfSignedDataTransfer(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
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
                        std.debug.panic("TODO: Implement SWP", .{});
                    },
                    0b01 => {
                        // LDRH
                        const halfword = bus.read16(address);
                        cpu.r[rd] = @as(u32, halfword);
                    },
                    0b10 => {
                        // LDRSB
                        const byte = bus.read8(address);
                        cpu.r[rd] = util.u32SignExtend(8, @as(u32, byte));
                    },
                    0b11 => {
                        // LDRSH
                        const halfword = bus.read16(address);
                        cpu.r[rd] = util.u32SignExtend(16, @as(u32, halfword));
                    },
                }
            } else {
                if (opcode >> 5 & 0x01 == 0x01) {
                    // STRH
                    const src = @truncate(u16, cpu.r[rd]);

                    bus.write16(address + 2, src);
                    bus.write16(address, src);
                } else {
                    std.debug.panic("TODO Figure out if this is also SWP", .{});
                }
            }

            address = modified_base;
            if (W and P) cpu.r[rn] = address;
        }
    }.halfSignedDataTransfer;
}
