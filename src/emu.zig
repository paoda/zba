const std = @import("std");

const Bus = @import("Bus.zig");
const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const Timer = std.time.Timer;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;

const cycles_per_frame: u64 = 160 * (308 * 4);
const clock_rate: u64 = 1 << 24;
const clock_period: u64 = std.time.ns_per_s / clock_rate;
const frame_period = (clock_period * cycles_per_frame);

const sync_to_video: bool = true;

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

    log.info("EmuThread has begun execution", .{});

    while (!quit.load(.Unordered)) {
        if (!pause.load(.Unordered)) {
            runFrame(sched, cpu, bus);

            const diff = timer.lap();

            var ns_late: u64 = undefined;
            const didUnderflow = @subWithOverflow(u64, diff, frame_period, &ns_late);

            // We were more than an entire frame late....
            if (!didUnderflow and ns_late > frame_period) continue;

            // Negate the u64 so that we add to the amount of time sleeping
            if (didUnderflow) ns_late = ~ns_late +% 1;

            if (sync_to_video) std.time.sleep(frame_period -% ns_late);
            fps.store(emuFps(diff), .Unordered);
        }
    }
}

fn emuFps(left: u64) u64 {
    @setRuntimeSafety(false);
    return @floatToInt(u64, @intToFloat(f64, std.time.ns_per_s) / @intToFloat(f64, left));
}
