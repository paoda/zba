const Bus = @import("Bus.zig");
const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const cycles_per_frame: u64 = 160 * (308 * 4);

pub fn runFrame(sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    var cycles: u64 = 0;
    while (cycles < cycles_per_frame) : (cycles += 1) {
        sched.tick += 1;
        _ = cpu.step();

        while (sched.tick >= sched.nextTimestamp()) {
            sched.handleEvent(cpu, bus);
        }
    }
}
