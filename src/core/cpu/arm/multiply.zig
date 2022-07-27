const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").arm.InstrFn;

pub fn multiply(comptime A: bool, comptime S: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            const rd = opcode >> 16 & 0xF;
            const rn = opcode >> 12 & 0xF;
            const rs = opcode >> 8 & 0xF;
            const rm = opcode & 0xF;

            const temp: u64 = @as(u64, cpu.r[rm]) * @as(u64, cpu.r[rs]) + if (A) cpu.r[rn] else 0;
            const result = @truncate(u32, temp);
            cpu.r[rd] = result;

            if (S) {
                cpu.cpsr.n.write(result >> 31 & 1 == 1);
                cpu.cpsr.z.write(result == 0);
                // V is unaffected, C is *actually* undefined in ARMv4
            }
        }
    }.inner;
}

pub fn multiplyLong(comptime U: bool, comptime A: bool, comptime S: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            const rd_hi = opcode >> 16 & 0xF;
            const rd_lo = opcode >> 12 & 0xF;
            const rs = opcode >> 8 & 0xF;
            const rm = opcode & 0xF;

            if (U) {
                // Signed (WHY IS IT U THEN?)
                var result: i64 = @as(i64, @bitCast(i32, cpu.r[rm])) * @as(i64, @bitCast(i32, cpu.r[rs]));
                if (A) result +%= @bitCast(i64, @as(u64, cpu.r[rd_hi]) << 32 | @as(u64, cpu.r[rd_lo]));

                cpu.r[rd_hi] = @bitCast(u32, @truncate(i32, result >> 32));
                cpu.r[rd_lo] = @bitCast(u32, @truncate(i32, result));
            } else {
                // Unsigned
                var result: u64 = @as(u64, cpu.r[rm]) * @as(u64, cpu.r[rs]);
                if (A) result +%= @as(u64, cpu.r[rd_hi]) << 32 | @as(u64, cpu.r[rd_lo]);

                cpu.r[rd_hi] = @truncate(u32, result >> 32);
                cpu.r[rd_lo] = @truncate(u32, result);
            }

            if (S) {
                cpu.cpsr.z.write(cpu.r[rd_hi] == 0 and cpu.r[rd_lo] == 0);
                cpu.cpsr.n.write(cpu.r[rd_hi] >> 31 & 1 == 1);
                // C and V are set to meaningless values
            }
        }
    }.inner;
}
