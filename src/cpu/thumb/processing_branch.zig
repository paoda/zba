const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

const cmp = @import("../arm/data_processing.zig").cmp;
const add = @import("../arm/data_processing.zig").add;

pub fn format5(comptime op: u2, comptime h1: u1, comptime h2: u1) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
            const src_idx = @as(u4, h2) << 3 | (opcode >> 3 & 0x7);
            const dst_idx = @as(u4, h1) << 3 | (opcode & 0x7);

            const src = if (src_idx == 0xF) (cpu.r[src_idx] + 2) & 0xFFFF_FFFE else cpu.r[src_idx];
            const dst = if (dst_idx == 0xF) (cpu.r[dst_idx] + 2) & 0xFFFF_FFFE else cpu.r[dst_idx];

            switch (op) {
                0b00 => {
                    // ADD
                    const sum = add(false, cpu, dst, src);
                    cpu.r[dst_idx] = if (dst_idx == 0xF) sum & 0xFFFF_FFFC else sum;
                },
                0b01 => cmp(cpu, dst, src), // CMP
                0b10 => {
                    // MOV
                    cpu.r[dst_idx] = if (dst_idx == 0xF) src & 0xFFFF_FFFC else src;
                },
                0b11 => {
                    // BX
                    cpu.cpsr.t.write(src & 1 == 1);
                    cpu.r[15] = src & 0xFFFF_FFFE;
                },
            }
        }
    }.inner;
}
