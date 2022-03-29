const std = @import("std");

const Bus = @import("Bus.zig");
const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const FpsAverage = @import("util.zig").FpsAverage;

const Timer = std.time.Timer;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;

// 228 Lines which consist of 308 dots (which are 4 cycles long)
const cycles_per_frame: u64 = 228 * (308 * 4); //280896
const clock_rate: u64 = 1 << 24; // 16.78MHz

// TODO: Don't truncate this, be more accurate w/ timing
// 59.6046447754ns (truncated to just 59ns)
const clock_period: u64 = std.time.ns_per_s / clock_rate;
const frame_period = (clock_period * cycles_per_frame);

// 59.7275005696Hz
pub const frame_rate = @intToFloat(f64, std.time.ns_per_s) /
    ((@intToFloat(f64, std.time.ns_per_s) / @intToFloat(f64, clock_rate)) * @intToFloat(f64, cycles_per_frame));

const log = std.log.scoped(.Emulation);

const RunKind = enum {
    Unlimited,
    UnlimitedFPS,
    Limited,
    LimitedFPS,
    LimitedBusy,
};

pub fn run(kind: RunKind, quit: *Atomic(bool), fps: *FpsAverage, sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    switch (kind) {
        .Unlimited => runUnsync(quit, sched, cpu, bus),
        .Limited => runSync(quit, sched, cpu, bus),
        .UnlimitedFPS => runUnsyncFps(quit, fps, sched, cpu, bus),
        .LimitedFPS => runSyncFps(quit, fps, sched, cpu, bus),
        .LimitedBusy => runBusyLoop(quit, sched, cpu, bus),
    }
}

pub fn runFrame(sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    const frame_end = sched.tick + cycles_per_frame;

    while (sched.tick < frame_end) {
        sched.tick += 1;
        _ = cpu.step();

        while (sched.tick >= sched.nextTimestamp()) {
            sched.handleEvent(cpu, bus);
        }
    }
}

pub fn runUnsync(quit: *Atomic(bool), sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    log.info("Unsynchronized EmuThread has begun", .{});
    while (!quit.load(.Unordered)) runFrame(sched, cpu, bus);
}

pub fn runSync(quit: *Atomic(bool), sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    log.info("Synchronized EmuThread has begun", .{});
    var timer = Timer.start() catch unreachable;
    var wake_time: u64 = frame_period;

    while (!quit.load(.Unordered)) {
        runFrame(sched, cpu, bus);

        // Put the Thread to Sleep + Backup Spin Loop
        // This saves on resource usage when frame limiting
        sleep(&timer, &wake_time);

        // Update to the new wake time
        wake_time += frame_period;
    }
}

pub fn runUnsyncFps(quit: *Atomic(bool), fps: *FpsAverage, sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    log.info("Unsynchronized EmuThread with FPS Tracking has begun", .{});
    var fps_timer = Timer.start() catch unreachable;

    while (!quit.load(.Unordered)) {
        runFrame(sched, cpu, bus);
        fps.add(fps_timer.lap());
    }
}

pub fn runSyncFps(quit: *Atomic(bool), fps: *FpsAverage, sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    log.info("Synchronized EmuThread has begun", .{});
    var timer = Timer.start() catch unreachable;
    var fps_timer = Timer.start() catch unreachable;
    var wake_time: u64 = frame_period;

    while (!quit.load(.Unordered)) {
        runFrame(sched, cpu, bus);

        // Put the Thread to Sleep + Backup Spin Loop
        // This saves on resource usage when frame limiting
        sleep(&timer, &wake_time);

        // Determine FPS
        fps.add(fps_timer.lap());

        // Update to the new wake time
        wake_time += frame_period;
    }
}

pub fn runBusyLoop(quit: *Atomic(bool), sched: *Scheduler, cpu: *Arm7tdmi, bus: *Bus) void {
    log.info("Run EmuThread with spin-loop sync", .{});
    var timer = Timer.start() catch unreachable;
    var wake_time: u64 = frame_period;

    while (!quit.load(.Unordered)) {
        runFrame(sched, cpu, bus);
        spinLoop(&timer, wake_time);

        // Update to the new wake time
        wake_time += frame_period;
    }
}

fn sleep(timer: *Timer, wake_time: *u64) void {
    // const step = std.time.ns_per_ms * 10; // 10ms
    const timestamp = timer.read();

    // ns_late is non zero if we are late.
    const ns_late = timestamp -| wake_time.*;

    // If we're more than a frame late, skip the rest of this loop
    // Recalculate what our new wake time should be so that we can
    // get "back on track"
    if (ns_late > frame_period) {
        wake_time.* = timestamp + frame_period;
        return;
    }

    const sleep_for = frame_period - ns_late;

    // // Employ several sleep calls in periods of 10ms
    // // By doing this the behaviour should average out to be
    // // more consistent
    // const loop_count = sleep_for / step; // How many groups of 10ms

    // var i: usize = 0;
    // while (i < loop_count) : (i += 1) std.time.sleep(step);

    std.time.sleep(sleep_for);

    // Spin to make up the difference if there is a need
    // Make sure that we're using the old wake time and not the onne we recalculated
    spinLoop(timer, wake_time.*);
}

fn spinLoop(timer: *Timer, wake_time: u64) void {
    while (true) if (timer.read() > wake_time) break;
}
