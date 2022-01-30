const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

const add = @import("../arm/data_processing.zig").add;
const sub = @import("../arm/data_processing.zig").sub;
const cmp = @import("../arm/data_processing.zig").cmp;
const setLogicOpFlags = @import("../arm/data_processing.zig").setLogicOpFlags;

pub fn format3(comptime op: u2, comptime rd: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const offset = @truncate(u8, opcode);

            switch (op) {
                0b00 => {
                    // MOV
                    cpu.r[rd] = offset;
                    setLogicOpFlags(true, cpu, offset);
                },
                0b01 => cmp(cpu, cpu.r[rd], offset), // CMP
                0b10 => cpu.r[rd] = add(true, cpu, cpu.r[rd], offset), // ADD
                0b11 => cpu.r[rd] = sub(true, cpu, cpu.r[rd], offset), // SUB
            }
        }
    }.inner;
}
