const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ArmInstrFn;

pub fn armSoftwareInterrupt() InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, _: u32) void {
            // Copy Values from Current Mode
            const r15 = cpu.r[15];
            const cpsr = cpu.cpsr.raw;

            // Switch Mode
            cpu.changeMode(.Supervisor);
            cpu.cpsr.t.write(false); // Force ARM Mode
            cpu.cpsr.i.write(true); // Disable normal interrupts

            cpu.r[14] = r15; // Resume Execution
            cpu.spsr.raw = cpsr; // Previous mode CPSR
            cpu.r[15] = 0x0000_0008;
        }
    }.inner;
}
