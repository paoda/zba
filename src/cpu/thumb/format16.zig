const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;
const checkCond = @import("../../cpu.zig").checkCond;
const u32SignExtend = @import("../../util.zig").u32SignExtend;

pub fn format16(comptime cond: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const offset = (opcode & 0xFF) << 1;

            const do_execute = switch (cond) {
                0xE, 0xF => std.debug.panic("[CPU/THUMB] Undefined conditional branch with condition {}", .{cond}),
                else => checkCond(cpu.cpsr, cond),
            };

            if (do_execute) cpu.r[15] = (cpu.fakePC() & 0xFFFF_FFFC) +% u32SignExtend(8, offset);
        }
    }.inner;
}
