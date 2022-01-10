const std = @import("std");

const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const InstrFn = @import("../cpu.zig").InstrFn;

pub fn blockDataTransfer(comptime P: bool, comptime U: bool, comptime S: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const rn = opcode >> 16 & 0xF;
            var base = cpu.r[rn];

            // TODO: For Performance (?) if U we got from 0 -> 0xF, if !U, 0xF -> 0
            // we can do this and have it be fast because of comptime, baby!

            if (!U) {
                var count: u32 = 0;
                var i: u5 = 0;
                while (i < 0x10) : (i += 1) {
                    count += opcode >> i & 1;
                }

                base -= count * 4;
            }

            var address = if (@boolToInt(P) ^ @boolToInt(U) == 0) base + 4 else base;
            if (S and opcode >> 15 & 1 == 0) std.debug.panic("[CPU] TODO: STM/LDM with S set but R15 not in transfer list", .{});

            var i: u5 = 0;
            while (i < 0x10) : (i += 1) {
                if (opcode >> i & 1 == 1) {
                    if (L) {
                        cpu.r[i] = bus.read32(address);
                        if (S and i == 0xF) std.debug.panic("[CPU] TODO: SPSR_<mode> is transferred to CPSR", .{});
                    } else {
                        if (i == 0xF) {
                            if (!S) {
                                // TODO: Assure that this is Address of STM instruction + 12
                                bus.write32(address, cpu.r[i] + (12 - 4));
                            } else {
                                std.debug.panic("[CPU] TODO: STM with S set and R15 in transfer list", .{});
                            }
                        } else {
                            bus.write32(address, cpu.r[i]);
                        }
                    }

                    address += 4;
                }
            }

            if (W and P or !P) cpu.r[rn] = if (U) address - 4 else base;
        }
    }.inner;
}
