const std = @import("std");

const Bus = @import("Bus.zig");
const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const Timer = std.time.Timer;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;

const cycles_per_frame: u64 = 228 * (308 * 4);
const clock_rate: u64 = 1 << 24;
const clock_period: u64 = std.time.ns_per_s / clock_rate;
const frame_period = (clock_period * cycles_per_frame);

const sync_to_video: bool = true;

// One frame operates at 59.7275005696Hz

const log = std.log.scoped(.Emulation);

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

pub fn runEmuThread(quit: *Atomic(bool), pause: *Atomic(bool), fps: *Atomic(u64), sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    var timer = Timer.start() catch unreachable;
    var fps_timer = Timer.start() catch unreachable;

    var wake_time: u64 = frame_period;

    log.info("EmuThread has begun execution", .{});

    while (!quit.load(.Unordered)) {
        if (!pause.load(.Unordered)) {
            runFrame(sched, cpu, bus);

            const timestamp = timer.read();
            fps.store(emuFps(fps_timer.lap()), .Unordered);

            // ns_late is non zero if we are late.
            var ns_late = timestamp -| wake_time;

            // Calculate the new Thread wake time
            wake_time += frame_period;

            // If we're more than a frame late, skip the rest of this loop
            if (ns_late > frame_period) continue;

            if (sync_to_video) std.time.sleep(frame_period - ns_late);

            // Backup Busy Loop Routine
            // if (sync_to_video) spinLoop(&timer, wake_time);
        }
    }
}

fn spinLoop(timer: *Timer, wake_time: u64) void {
    while (true) {
        const timestamp = timer.read();

        if (timestamp >= wake_time) {
            break;
        }
    }
}

fn emuFps(left: u64) u64 {
    @setRuntimeSafety(false);
    return @floatToInt(u64, @intToFloat(f64, std.time.ns_per_s) / @intToFloat(f64, left));
}
