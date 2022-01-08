const util = @import("../util.zig");

const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const InstrFn = @import("../cpu.zig").InstrFn;

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
