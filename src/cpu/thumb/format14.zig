const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format14(comptime L: bool, comptime R: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            var address: u32 = undefined;
            if (L) {
                // POP
                address = cpu.r[13];

                var i: usize = 0;
                while (i < 8) : (i += 1) {
                    if ((opcode >> @truncate(u3, i)) & 1 == 1) {
                        cpu.r[i] = bus.read32(address);
                        address += 4;
                    }
                }

                if (R) {
                    const value = bus.read32(address);
                    cpu.r[15] = value & 0xFFFF_FFFE;
                    address += 4;
                }
            } else {
                address = cpu.r[13] - 4;

                if (R) {
                    bus.write32(address, cpu.r[14]);
                    address -= 4;
                }

                var i: usize = 8;
                while (i > 0) : (i -= 1) {
                    const j = i - 1;

                    if ((opcode >> @truncate(u3, j)) & 1 == 1) {
                        bus.write32(address, cpu.r[j]);
                        address -= 4;
                    }
                }
            }

            cpu.r[13] = address;
        }
    }.inner;
}
