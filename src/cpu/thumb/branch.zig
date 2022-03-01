const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

const checkCond = @import("../../cpu.zig").checkCond;
const sext = @import("../../util.zig").sext;

pub fn format16(comptime cond: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // B
            const offset = sext(8, opcode & 0xFF) << 1;

            const should_execute = switch (cond) {
                0xE, 0xF => cpu.panic("[CPU/THUMB.16] Undefined conditional branch with condition {}", .{cond}),
                else => checkCond(cpu.cpsr, cond),
            };

            if (should_execute) {
                cpu.r[15] = (cpu.r[15] + 2) +% offset;
            }
        }
    }.inner;
}

pub fn format18() InstrFn {
    return struct {
        // B but conditional
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const offset = sext(11, opcode & 0x7FF) << 1;
            cpu.r[15] = (cpu.r[15] + 2) +% offset;
        }
    }.inner;
}

pub fn format19(comptime is_low: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // BL
            const offset = opcode & 0x7FF;

            if (is_low) {
                // Instruction 2
                const old_pc = cpu.r[15];

                cpu.r[15] = cpu.r[14] +% (offset << 1);
                cpu.r[14] = old_pc | 1;
            } else {
                // Instruction 1
                cpu.r[14] = (cpu.r[15] + 2) +% (sext(11, offset) << 12);
            }
        }
    }.inner;
}
