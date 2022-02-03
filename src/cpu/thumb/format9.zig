const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

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
