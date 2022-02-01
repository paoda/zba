const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format10(comptime L: bool, comptime offset: u5) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const rb = opcode >> 3 & 0x7;
            const rd = opcode & 0x7;

            const address = cpu.r[rb] + (offset << 1);

            if (L) {
                // LDRH
                cpu.r[rd] = bus.read16(address & 0xFFFF_FFFE);
            } else {
                // STRH
                bus.write16(address & 0xFFFF_FFFE, @truncate(u16, cpu.r[rd]));
            }
        }
    }.inner;
}
