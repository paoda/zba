const std = @import("std");
const util = @import("../../util.zig");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").InstrFn;

pub fn branch(comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            if (L) {
                // TODO: Debugging beeg.gba w/ MGBA seems to suggest that I don't do anything here
                cpu.r[14] = cpu.r[15];
            }

            cpu.r[15] = cpu.fakePC() +% util.u32SignExtend(24, opcode << 2);
        }
    }.inner;
}

pub fn branchAndExchange(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
    const rn = opcode & 0xF;
    cpu.cpsr.t.write(cpu.r[rn] & 1 == 1);

    // TODO: Is this how I should do it?
    cpu.r[15] = cpu.r[rn] & 0xFFFF_FFFE;
}
