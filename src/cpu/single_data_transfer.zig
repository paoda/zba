const std = @import("std");
const util = @import("../util.zig");
const mod_cpu = @import("../cpu.zig");

const ARM7TDMI = mod_cpu.ARM7TDMI;
const InstrFn = mod_cpu.InstrFn;
const Bus = @import("../bus.zig").Bus;

pub fn comptimeSingleDataTransfer(comptime I: bool, comptime P: bool, comptime U: bool, comptime B: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn singleDataTransfer(cpu: *ARM7TDMI, bus: *Bus, opcode: u32) void {
            const rn = opcode >> 16 & 0xF;
            const rd = opcode >> 12 & 0xF;

            const base = cpu.r[rn];
            const offset = if (I) opcode & 0xFFF else registerOffset(cpu, opcode);

            const modified_base = if (U) base + offset else base - offset;
            var address = if (P) modified_base else base;

            if (L) {
                if (B) {
                    // LDRB
                    cpu.r[rd] = bus.readByte(address);
                } else {
                    // LDR
                    std.debug.panic("Implement LDR", .{});
                }
            } else {
                if (B) {
                    // STRB
                    const src = @truncate(u8, cpu.r[rd]);

                    bus.writeByte(address + 3, src);
                    bus.writeByte(address + 2, src);
                    bus.writeByte(address + 1, src);
                    bus.writeByte(address, src);
                } else {
                    // STR
                    std.debug.panic("Implement STR", .{});
                }
            }

            address = modified_base;
            if (W and P) cpu.r[rn] = address;

            // TODO: W-bit forces non-privledged mode for the transfer
        }
    }.singleDataTransfer;
}

fn registerOffset(cpu: *ARM7TDMI, opcode: u32) u32 {
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
