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
                    cpu.r[rd] = offset;

                    cpu.cpsr.n.unset();
                    cpu.cpsr.z.write(offset == 0);
                },
                0b01 => {
                    std.debug.panic("TODO: Implement cmp R{}, #0x{X:0>2}", .{ rd, offset });
                },
                0b10 => {
                    std.debug.panic("TODO: Implement add R{}, #0x{X:0>2}", .{ rd, offset });
                },
                0b11 => {
                    std.debug.panic("TODO: Implement sub R{}, #0x{X:0>2}", .{ rd, offset });
                },
            }
        }
    }.inner;
}
