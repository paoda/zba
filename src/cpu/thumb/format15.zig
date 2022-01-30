const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format15(comptime L: bool, comptime rb: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const base = cpu.r[rb];

            var address: u32 = base;

            var i: usize = 0;
            while (i < 8) : (i += 1) {
                if ((opcode >> @truncate(u3, i)) & 1 == 1) {
                    if (L) {
                        cpu.r[i] = bus.read32(address);
                    } else {
                        bus.write32(address, cpu.r[i]);
                    }
                    address += 4;
                }
            }

            cpu.r[rb] = address;
        }
    }.inner;
}
