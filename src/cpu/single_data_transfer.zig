const std = @import("std");
const util = @import("../util.zig");
const processor = @import("../cpu.zig");

const Bus = @import("../bus.zig").Bus;
const Arm7tdmi = processor.Arm7tdmi;
const InstrFn = processor.InstrFn;

pub fn comptimeSingleDataTransfer(comptime I: bool, comptime P: bool, comptime U: bool, comptime B: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn singleDataTransfer(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const rn = opcode >> 16 & 0xF;
            const rd = opcode >> 12 & 0xF;

            const base = cpu.r[rn];
            const offset = if (I) registerOffset(cpu, opcode) else opcode & 0xFFF;

            const modified_base = if (U) base + offset else base - offset;
            var address = if (P) modified_base else base;

            if (L) {
                if (B) {
                    // LDRB
                    cpu.r[rd] = bus.read8(address);
                } else {
                    // LDR

                    // FIXME: Unsure about how I calculate the boundary offset
                    cpu.r[rd] = std.math.rotl(u32, bus.read32(address), address % 4);
                }
            } else {
                if (B) {
                    // STRB
                    bus.write8(address, @truncate(u8, cpu.r[rd]));
                } else {
                    // STR
                    const force_aligned = address & 0xFFFF_FFFC;
                    bus.write32(force_aligned, cpu.r[rd]);
                }
            }

            address = modified_base;
            if (W and P or !W) cpu.r[rn] = address;

            // TODO: W-bit forces non-privledged mode for the transfer
        }
    }.singleDataTransfer;
}

fn registerOffset(cpu: *Arm7tdmi, opcode: u32) u32 {
    const amount = opcode >> 7 & 0x1F;
    const rm = opcode & 0xF;
    const r_val = cpu.r[rm];

    return switch (opcode >> 5 & 0x03) {
        0b00 => r_val << @truncate(u5, amount),
        0b01 => r_val >> @truncate(u5, amount),
        0b10 => @bitCast(u32, @bitCast(i32, r_val) >> @truncate(u5, amount)),
        0b11 => std.math.rotr(u32, r_val, amount),
        else => unreachable,
    };
}
