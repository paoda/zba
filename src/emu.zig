const _ = @import("std");

const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Bus = @import("bus.zig").Bus;

const cycles_per_frame: u64 = 10_000; // TODO: How many cycles actually?

pub fn runFrame(sch: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    const frame_end = sch.tick + cycles_per_frame;

    while (sch.tick < frame_end) {
        while (sch.tick < sch.nextTimestamp()) {
            sch.tick += cpu.step();
        }

        sch.handleEvent(cpu, bus);
    }
}
