const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format13(comptime S: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const offset = (opcode & 0x7F) << 2;
            cpu.r[13] = if (S) cpu.r[13] - offset else cpu.r[13] + offset;
        }
    }.inner;
}
