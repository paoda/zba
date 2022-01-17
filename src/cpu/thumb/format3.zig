const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format3(comptime op: u2, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const offset = @truncate(u8, opcode);

            switch (op) {
                0b00 => {
                    // MOV
                    cpu.r[rd] = offset;

                    cpu.cpsr.n.unset();
                    cpu.cpsr.z.write(offset == 0);
                },
                0b01 => {
                    // CMP
                    const left = cpu.r[rd];
                    const result = left -% offset;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(offset <= left);
                    cpu.cpsr.v.write(((left ^ result) & (~offset ^ result)) >> 31 & 1 == 1);
                },
                0b10 => {
                    // ADD
                    const left = cpu.r[rd];

                    var result: u32 = undefined;
                    const didOverflow = @addWithOverflow(u32, left, offset, &result);
                    cpu.r[rd] = result;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(didOverflow);
                    cpu.cpsr.v.write(((left ^ result) & (offset ^ result)) >> 31 & 1 == 1);
                },
                0b11 => {
                    // SUB
                    const left = cpu.r[rd];
                    const result = left -% offset;
                    cpu.r[rd] = result;

                    cpu.cpsr.n.write(result >> 31 & 1 == 1);
                    cpu.cpsr.z.write(result == 0);
                    cpu.cpsr.c.write(offset <= left);
                    cpu.cpsr.v.write(((left ^ result) & (~offset ^ result)) >> 31 & 1 == 1);
                },
            }
        }
    }.inner;
}
