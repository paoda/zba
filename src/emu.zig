const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Bus = @import("bus.zig").Bus;

const cycles_per_frame: u64 = 100; // TODO: How many cycles actually?

pub fn runFrame(sch: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    var cycles: u64 = 0;
    while (cycles < cycles_per_frame) : (cycles += 1) {
        sch.tick += 1;
        _ = cpu.step();

        while (sch.tick >= sch.nextTimestamp()) {
            sch.handleEvent(cpu, bus);
        }
    }
}
