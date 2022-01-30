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
