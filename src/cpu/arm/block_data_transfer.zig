const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

pub fn blockDataTransfer(comptime P: bool, comptime U: bool, comptime S: bool, comptime W: bool, comptime L: bool) InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, bus: *Bus, opcode: u32) void {
            const r15_present = opcode >> 15 & 1 == 1;
            const rn = opcode >> 16 & 0xF;
            const base = cpu.r[rn];

            var address: u32 = undefined;
            if (U) {
                // Increment
                address = if (P) base + 4 else base;

                var i: u5 = 0;
                while (i < 0x10) : (i += 1) {
                    if (opcode >> i & 1 == 1) {
                        transfer(cpu, bus, r15_present, i, address);
                        address += 4;
                    }
                }
            } else {
                // Decrement
                address = if (P) base - 4 else base;

                var i: u5 = 0x10;
                while (i > 0) : (i -= 1) {
                    const j = i - 1;

                    if (opcode >> j & 1 == 1) {
                        transfer(cpu, bus, r15_present, j, address);
                        address -= 4;
                    }
                }
            }

            if (W and P or !P) cpu.r[rn] = if (U) address else address + 4;
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
