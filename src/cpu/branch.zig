const arm = @import("../cpu.zig");
const util = @import("../util.zig");

const Bus = @import("../bus.zig").Bus;

const Arm7tdmi = arm.Arm7tdmi;
const InstrFn = arm.InstrFn;

pub fn branch(comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            if (L) {
                cpu.r[14] = cpu.r[15] - 4;
            }

            cpu.r[15] = cpu.fakePC() +% util.u32SignExtend(24, opcode << 2);
        }
    }.inner;
}
