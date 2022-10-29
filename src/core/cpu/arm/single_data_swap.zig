const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").arm.InstrFn;

const rotr = @import("../../../util.zig").rotr;

pub fn singleDataSwap(comptime B: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const rn = opcode >> 16 & 0xF;
            const rd = opcode >> 12 & 0xF;
            const rm = opcode & 0xF;

            const address = cpu.r[rn];

            if (B) {
                // SWPB
                const value = bus.read(u8, address);
                bus.write(u8, address, @truncate(u8, cpu.r[rm]));
                cpu.r[rd] = value;
            } else {
                // SWP
                const value = rotr(u32, bus.read(u32, address), 8 * (address & 0x3));
                bus.write(u32, address, cpu.r[rm]);
                cpu.r[rd] = value;
            }
        }
    }.inner;
}
