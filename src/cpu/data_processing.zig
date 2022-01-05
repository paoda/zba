const std = @import("std");
const arm = @import("../cpu.zig");

const BarrelShifter = @import("barrel_shifter.zig");
const Bus = @import("../bus.zig").Bus;
const Arm7tdmi = arm.Arm7tdmi;
const InstrFn = arm.InstrFn;

pub fn comptimeDataProcessing(comptime I: bool, comptime S: bool, comptime instrKind: u4) InstrFn {
    return struct {
        fn dataProcessing(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            const rd = opcode >> 12 & 0xF;
            const op1 = opcode >> 16 & 0xF;

            var op2: u32 = undefined;
            if (I) {
                op2 = std.math.rotr(u32, opcode & 0xFF, (opcode >> 8 & 0xF) << 1);
            } else {
                op2 = BarrelShifter.exec(cpu, opcode);
            }

            switch (instrKind) {
                0x4 => {
                    // ADD
                    cpu.r[rd] = cpu.r[op1] + op2;

                    if (S) std.debug.panic("[CPU] TODO: implement ADD condition codes", .{});
                },
                0x8 => {
                    // TST
                    std.debug.panic("[CPU] TODO: implement TST, also figure out barrel shifter flags\n", .{});
                },
                0xD => {
                    // MOV
                    cpu.r[rd] = op2;

                    if (S) std.debug.panic("[CPU] implement MOV condition codes", .{});
                },
                0xA => {
                    // CMP
                    const op1_val = cpu.r[op1];
                    const v_ctx = (op1_val >> 31 == 1) or (op2 >> 31 == 1);

                    const result = op1_val -% op2;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(op2 <= op1_val);
                    cpu.cpsr.v.write(v_ctx and (result >> 31 & 1 == 1));
                },
                else => std.debug.panic("[CPU] TODO: implement data processing type {}", .{instrKind}),
            }
        }
    }.dataProcessing;
}

// fn registerOp2(cpu: *const Arm7tdmi, opcode: u32) u32 {
//     var amount: u32 = undefined;
//     if (opcode >> 4 & 0x01 == 0x01) {
//         amount = cpu.r[opcode >> 8 & 0xF] & 0xFF;
//     } else {
//         amount = opcode >> 7 & 0x1F;
//     }

//     const rm = opcode & 0xF;
//     const r_val = cpu.r[rm];

//     return switch (opcode >> 5 & 0x03) {
//         0b00 => r_val << @truncate(u5, amount),
//         0b01 => r_val >> @truncate(u5, amount),
//         0b10 => @bitCast(u32, @bitCast(i32, r_val) >> @truncate(u5, amount)),
//         0b11 => std.math.rotr(u32, r_val, amount),
//         else => unreachable,
//     };
// }
