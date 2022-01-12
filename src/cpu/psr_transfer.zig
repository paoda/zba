const std = @import("std");

const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const InstrFn = @import("../cpu.zig").InstrFn;

pub fn psrTransfer(comptime I: bool, comptime isSpsr: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            switch (@truncate(u3, opcode >> 19)) {
                0b001 => {
                    // MRS
                    const rn = opcode >> 12 & 0xF;

                    if (isSpsr) {
                        std.debug.panic("[CPU] TODO: MRS on SPSR_<current_mode> is unimplemented", .{});
                    } else {
                        cpu.r[rn] = cpu.cpsr.raw;
                    }
                },
                0b101 => {
                    // MSR
                    const rm = opcode & 0xF;

                    switch (@truncate(u3, opcode >> 16)) {
                        0b000 => {
                            const right = if (I) std.math.rotr(u32, opcode & 0xFF, opcode >> 8 & 0xF) else cpu.r[rm];

                            if (isSpsr) {
                                std.debug.panic("[CPU] TODO: MSR (flags only) on SPSR_<current_mode> is unimplemented", .{});
                            } else {
                                cpu.cpsr.n.write(right >> 31 & 1 == 1);
                                cpu.cpsr.z.write(right >> 30 & 1 == 1);
                                cpu.cpsr.c.write(right >> 29 & 1 == 1);
                                cpu.cpsr.v.write(right >> 28 & 1 == 1);
                            }
                        },
                        0b001 => {
                            if (isSpsr) {
                                std.debug.panic("[CPU] TODO: MSR on SPSR_<current_mode> is unimplemented", .{});
                            } else {
                                cpu.cpsr = .{ .raw = cpu.r[rm] };
                            }
                        },

                        else => unreachable,
                    }
                },
                else => unreachable,
            }
        }
    }.inner;
}
