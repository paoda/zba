const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

pub fn blockDataTransfer(comptime P: bool, comptime U: bool, comptime S: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const rn = @truncate(u4, opcode >> 16 & 0xF);
            const rlist = opcode & 0xFFFF;
            const r15 = rlist >> 15 & 1 == 1;

            var count: u32 = 0;
            var i: u5 = 0;
            var first: u4 = 0;
            var write_to_base = true;

            while (i < 16) : (i += 1) {
                const r = @truncate(u4, 15 - i);
                if (rlist >> r & 1 == 1) {
                    first = r;
                    count += 1;
                }
            }

            var start = cpu.r[rn];
            if (U) {
                start += if (P) 4 else 0;
            } else {
                start = start - (4 * count) + if (!P) 4 else 0;
            }

            var end = cpu.r[rn];
            if (U) {
                end = end + (4 * count) - if (!P) 4 else 0;
            } else {
                end -= if (P) 4 else 0;
            }

            var new_base = cpu.r[rn];
            if (U) {
                new_base += 4 * count;
            } else {
                new_base -= 4 * count;
            }

            var address = start;

            if (rlist == 0) {
                var pc_addr = cpu.r[rn];
                if (U) {
                    pc_addr += if (P) 4 else 0;
                } else {
                    pc_addr -= 0x40 - if (!P) 4 else 0;
                }

                if (L) {
                    cpu.r[15] = bus.read32(pc_addr);
                } else {
                    bus.write32(pc_addr, cpu.r[15] + 8);
                }

                cpu.r[rn] = if (U) cpu.r[rn] + 0x40 else cpu.r[rn] - 0x40;
                return;
            }

            i = first;
            while (i < 16) : (i += 1) {
                if (rlist >> i & 1 == 1) {
                    transfer(cpu, bus, r15, i, address);
                    address += 4;

                    if (W and !L and write_to_base) {
                        cpu.r[rn] = new_base;
                        write_to_base = false;
                    }
                }
            }

            if (W and L and rlist >> rn & 1 == 0) cpu.r[rn] = new_base;
        }

        fn transfer(cpu: *Arm7tdmi, bus: *Bus, r15_present: bool, i: u5, address: u32) void {
            if (L) {
                if (S and !r15_present) {
                    // Always Transfer User mode Registers
                    cpu.setUserModeRegister(i, bus.read32(address));
                } else {
                    const value = bus.read32(address);
                    cpu.r[i] = if (i == 0xF) value & 0xFFFF_FFFC else value;
                    if (S and i == 0xF) cpu.setCpsr(cpu.spsr.raw);
                }
            } else {
                if (S) {
                    // Always Transfer User mode Registers
                    // This happens regardless if r15 is in the list
                    const value = cpu.getUserModeRegister(i);
                    bus.write32(address, value + if (i == 0xF) 8 else @as(u32, 0)); // PC is already 4 ahead to make 12
                } else {
                    bus.write32(address, cpu.r[i] + if (i == 0xF) 8 else @as(u32, 0));
                }
            }
        }
    }.inner;
}
