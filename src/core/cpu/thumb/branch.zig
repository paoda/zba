const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").thumb.InstrFn;

const checkCond = @import("../../cpu.zig").checkCond;
const sext = @import("../../../util.zig").sext;

pub fn fmt16(comptime cond: u4) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // B
            if (cond == 0xE or cond == 0xF)
                cpu.panic("[CPU/THUMB.16] Undefined conditional branch with condition {}", .{cond});

            if (!checkCond(cpu.cpsr, cond)) return;

            cpu.r[15] +%= sext(u32, u8, opcode & 0xFF) << 1;
            cpu.pipe.reload(u16, cpu);
        }
    }.inner;
}

pub fn fmt18() InstrFn {
    return struct {
        // B but conditional
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            cpu.r[15] +%= sext(u32, u11, opcode & 0x7FF) << 1;
            cpu.pipe.reload(u16, cpu);
        }
    }.inner;
}

pub fn fmt19(comptime is_low: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            // BL
            const offset = opcode & 0x7FF;

            if (is_low) {
                // Instruction 2
                const next_opcode = cpu.r[15] - 2;

                cpu.r[15] = cpu.r[14] +% (offset << 1);
                cpu.r[14] = next_opcode | 1;

                cpu.pipe.reload(u16, cpu);
            } else {
                // Instruction 1
                const lr_offset = sext(u32, u11, offset) << 12;
                cpu.r[14] = (cpu.r[15] +% lr_offset) & ~@as(u32, 1);
            }
        }
    }.inner;
}
