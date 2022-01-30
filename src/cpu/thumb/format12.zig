const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format12(comptime isSP: bool, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // ADD
            const left = if (isSP) cpu.r[13] else (cpu.r[15] + 2) & 0xFFFF_FFFD;
            const right = (opcode & 0xFF) << 2;
            const result = left + right; // TODO: What about overflows?
            cpu.r[rd] = result;
        }
    }.inner;
}
