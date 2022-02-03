const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format11(comptime L: bool, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const offset = (opcode & 0xFF) << 2;
            const address = cpu.r[13] + offset;

            if (L) {
                const value = bus.read32(address & 0xFFFF_FFFC);
                cpu.r[rd] = std.math.rotr(u32, value, 8 * (address & 0x3));
            } else {
                bus.write32(address & 0xFFFF_FFFC, cpu.r[rd]);
            }
        }
    }.inner;
}
