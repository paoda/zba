const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").thumb.InstrFn;

pub fn fmt17() InstrFn {
    return struct {
        fn inner(cpu: *Arm7tdmi, _: *Bus, _: u16) void {
            // Copy Values from Current Mode
            const ret_addr = cpu.r[15] - 2;
            const cpsr = cpu.cpsr.raw;

            // Switch Mode
            cpu.changeMode(.Supervisor);
            cpu.cpsr.t.write(false); // Force ARM Mode
            cpu.cpsr.i.write(true); // Disable normal interrupts

            cpu.r[14] = ret_addr; // Resume Execution
            cpu.spsr.raw = cpsr; // Previous mode CPSR
            cpu.r[15] = 0x0000_0008;
            cpu.pipe.reload(cpu);
        }
    }.inner;
}
