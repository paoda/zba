const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;
const PSR = @import("../../cpu.zig").PSR;

pub fn psrTransfer(comptime I: bool, comptime R: bool, comptime kind: u2) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            switch (kind) {
                0b00 => {
                    // MRS
                    const rd = opcode >> 12 & 0xF;

                    if (R) {
                        std.debug.panic("[CPU/PSR Transfer] TODO: MRS on SPSR_<current_mode> is unimplemented", .{});
                    } else {
                        cpu.r[rd] = cpu.cpsr.raw;
                    }
                },
                0b10 => {
                    // MSR
                    const field_mask = @truncate(u4, opcode >> 16 & 0xF);

                    if (I) {
                        const imm = std.math.rotr(u32, opcode & 0xFF, (opcode >> 8 & 0xF) << 1);

                        if (R) {
                            std.debug.panic("[CPU/PSR Transfer] TODO: MSR (flags only) on SPSR_<current_mode> is unimplemented", .{});
                        } else {
                            cpu.cpsr.raw = fieldMask(&cpu.cpsr, field_mask, imm);
                        }
                    } else {
                        const rm_idx = opcode & 0xF;

                        if (R) {
                            std.debug.panic("[CPU/PSR Transfer] TODO: MSR on SPSR_<current_mode> is unimplemented", .{});
                        } else {
                            cpu.cpsr.raw = fieldMask(&cpu.cpsr, field_mask, cpu.r[rm_idx]);
                        }
                    }
                },
                else => std.debug.panic("[CPU/PSR Transfer] Bits 21:220 of {X:0>8} are undefined", .{opcode}),
            }
        }
    }.inner;
}

fn fieldMask(psr: *const PSR, field_mask: u4, right: u32) u32 {
    const bits = @truncate(u2, (field_mask >> 2 & 0x2) | (field_mask & 1));

    const mask: u32 = switch (bits) {
        0b00 => 0x0000_0000,
        0b01 => 0x0000_00FF,
        0b10 => 0xF000_0000,
        0b11 => 0xF000_00FF,
    };

    return (psr.raw & ~mask) | (right & mask);
}
