const _ = @import("std");

const Scheduler = @import("scheduler.zig").Scheduler;
const ARM7TDMI = @import("cpu.zig").ARM7TDMI;
const Bus = @import("bus.zig").Bus;

const CYCLES_PER_FRAME: u64 = 10_000; // TODO: What is this?

pub fn runFrame(sch: *Scheduler, cpu: *ARM7TDMI, bus: *Bus) void {
    const frame_end = sch.tick + CYCLES_PER_FRAME;

    while (sch.tick < frame_end) {
        while (sch.tick < sch.nextTimestamp()) {
            sch.tick += cpu.step();
        }

        sch.handleEvent(cpu, bus);
    }
}
