const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;
const u32SignExtend = @import("../../util.zig").u32SignExtend;

pub fn format18() InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const offset = u32SignExtend(11, opcode & 0x7FF) << 1;
            cpu.r[15] = (cpu.r[15] + 2) +% offset;
        }
    }.inner;
}
