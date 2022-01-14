const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

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
                            const right = if (I) std.math.rotr(u32, opcode & 0xFF, opcode >> 7 & 0xF) else cpu.r[rm];

                            if (isSpsr) {
                                std.debug.panic("[CPU] TODO: MSR (flags only) on SPSR_<current_mode> is unimplemented", .{});
                            } else {
                                const mask: u32 = 0xF000_0000;
                                cpu.cpsr.raw = (cpu.cpsr.raw & ~mask) | (right & mask);
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
