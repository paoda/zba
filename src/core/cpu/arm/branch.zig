const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").arm.InstrFn;

const sext = @import("zba-util").sext;

pub fn branch(comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            if (L) cpu.r[14] = cpu.r[15] - 4;

            cpu.r[15] +%= sext(u32, u24, opcode) << 2;
            cpu.pipe.reload(cpu);
        }
    }.inner;
}

pub fn branchAndExchange(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
    const rn = opcode & 0xF;

    const thumb = cpu.r[rn] & 1 == 1;
    cpu.r[15] = cpu.r[rn] & if (thumb) ~@as(u32, 1) else ~@as(u32, 3);

    cpu.cpsr.t.write(thumb);
    cpu.pipe.reload(cpu);
}
