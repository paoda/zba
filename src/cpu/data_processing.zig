const std = @import("std");
const cpu_mod = @import("../cpu.zig");

const Bus = @import("../bus.zig").Bus;
const ARM7TDMI = cpu_mod.ARM7TDMI;
const InstrFn = cpu_mod.InstrFn;

pub fn comptimeDataProcessing(comptime I: bool, comptime S: bool, comptime instrKind: u4) InstrFn {
    return struct {
        fn dataProcessing(cpu: *ARM7TDMI, _: *Bus, opcode: u32) void {
            const rd = opcode >> 12 & 0xF;
            const op1 = opcode >> 16 & 0xF;

            var op2: u32 = undefined;
            if (I) {
                op2 = std.math.rotr(u32, opcode & 0xFF, (opcode >> 8 & 0xF) << 1);
            } else {
                op2 = reg_op2(cpu, opcode);
            }

            switch (instrKind) {
                0x4 => {
                    cpu.r[rd] = cpu.r[op1] + op2;

                    if (S) std.debug.panic("TODO: implement ADD condition codes", .{});
                },
                0xD => {
                    cpu.r[rd] = op2;

                    if (S) std.debug.panic("TODO: implement MOV condition codes", .{});
                },
                else => std.debug.panic("TODO: implement data processing type {}", .{instrKind}),
            }
        }
    }.dataProcessing;
}

fn reg_op2(cpu: *const ARM7TDMI, opcode: u32) u32 {
    var amount: u32 = undefined;
    if (opcode >> 4 & 0x01 == 0x01) {
        amount = cpu.r[opcode >> 8 & 0xF] & 0xFF;
    } else {
        amount = opcode >> 7 & 0x1F;
    }

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
