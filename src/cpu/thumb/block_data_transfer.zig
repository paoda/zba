const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format14(comptime L: bool, comptime R: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            const count = @boolToInt(R) + countRlist(opcode);
            const start = cpu.r[13] - if (!L) count * 4 else 0;

            var end = cpu.r[13];
            if (L) {
                end += count * 4;
            } else {
                end -= 4;
            }

            var address = start;

            var i: u4 = 0;
            while (i < 8) : (i += 1) {
                if (opcode >> i & 1 == 1) {
                    if (L) {
                        cpu.r[i] = bus.read32(address & 0xFFFF_FFFC);
                    } else {
                        bus.write32(address & 0xFFFF_FFFC, cpu.r[i]);
                    }

                    address += 4;
                }
            }

            if (R) {
                if (L) {
                    const value = bus.read32(address & 0xFFFF_FFFC);
                    cpu.r[15] = value & 0xFFFF_FFFE;
                } else {
                    bus.write32(address & 0xFFFF_FFFC, cpu.r[14]);
                }
                address += 4;
            }

            cpu.r[13] = if (L) end else start;
        }
    }.inner;
}

pub fn format15(comptime L: bool, comptime rb: u3) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u16) void {
            var address = cpu.r[rb];
            const end_address = cpu.r[rb] + 4 * countRlist(opcode);

            if (opcode & 0xFF == 0) {
                if (L) cpu.r[15] = bus.read32(address & 0xFFFF_FFFC) else bus.write32(address & 0xFFFF_FFFC, cpu.r[15] + 4);
                cpu.r[rb] += 0x40;
                return;
            }

            var i: u4 = 0;
            var first_write = true;

            while (i < 8) : (i += 1) {
                if (opcode >> i & 1 == 1) {
                    if (L) {
                        cpu.r[i] = bus.read32(address & 0xFFFF_FFFC);
                    } else {
                        bus.write32(address & 0xFFFF_FFFC, cpu.r[i]);
                    }

                    if (!L and first_write) {
                        cpu.r[rb] = end_address;
                        first_write = false;
                    }

                    address += 4;
                }
            }

            if (L and opcode >> rb & 1 != 1) cpu.r[rb] = address;
        }
    }.inner;
}

inline fn countRlist(opcode: u16) u32 {
    var count: u32 = 0;

    comptime var i: u4 = 0;
    inline while (i < 8) : (i += 1) {
        if (opcode >> (7 - i) & 1 == 1) count += 1;
    }

    return count;
}
