const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;
const PSR = @import("../../cpu.zig").PSR;

const log = std.log.scoped(.PsrTransfer);

const rotr = @import("../../util.zig").rotr;

pub fn psrTransfer(comptime I: bool, comptime R: bool, comptime kind: u2) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            switch (kind) {
                0b00 => {
                    // MRS
                    const rd = opcode >> 12 & 0xF;

                    if (R and !cpu.hasSPSR()) log.err("Tried to read SPSR from User/System Mode", .{});
                    cpu.r[rd] = if (R) cpu.spsr.raw else cpu.cpsr.raw;
                },
                0b10 => {
                    // MSR
                    const field_mask = @truncate(u4, opcode >> 16 & 0xF);
                    const rm_idx = opcode & 0xF;
                    const right = if (I) rotr(u32, opcode & 0xFF, (opcode >> 8 & 0xF) << 1) else cpu.r[rm_idx];

                    if (R and !cpu.hasSPSR()) log.err("Tried to write to SPSR in User/System Mode", .{});

                    if (R) {
                        if (cpu.isPrivileged()) cpu.spsr.raw = fieldMask(&cpu.spsr, field_mask, right);
                    } else {
                        if (cpu.isPrivileged()) cpu.setCpsr(fieldMask(&cpu.cpsr, field_mask, right));
                    }
                },
                else => cpu.panic("[CPU/PSR Transfer] Bits 21:220 of {X:0>8} are undefined", .{opcode}),
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
