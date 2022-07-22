const std = @import("std");
const SDL = @import("sdl2");

const Bus = @import("Bus.zig");
const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const FpsTracker = @import("util.zig").FpsTracker;
const FilePaths = @import("util.zig").FilePaths;

const Timer = std.time.Timer;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;
const Allocator = std.mem.Allocator;

const sync_audio = false;
const sync_video: RunKind = .UnlimitedFPS;

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

pub fn run(quit: *Atomic(bool), fps: *FpsTracker, sched: *Scheduler, cpu: *Arm7tdmi) void {
    if (sync_audio) log.info("Audio sync enabled", .{});

    switch (sync_video) {
        .Unlimited => runUnsynchronized(quit, sched, cpu, null),
        .Limited => runSynchronized(quit, sched, cpu, null),
        .UnlimitedFPS => runUnsynchronized(quit, sched, cpu, fps),
        .LimitedFPS => runSynchronized(quit, sched, cpu, fps),
        .LimitedBusy => runBusyLoop(quit, sched, cpu),
    }
}

pub fn runFrame(sched: *Scheduler, cpu: *Arm7tdmi) void {
    const frame_end = sched.tick + cycles_per_frame;

    while (sched.tick < frame_end) {
        if (!cpu.stepDmaTransfer()) {
            if (cpu.isHalted()) {
                // Fast-forward to next Event
                sched.tick = sched.queue.peek().?.tick;
            } else {
                cpu.step();
            }
        }

        if (sched.tick >= sched.nextTimestamp()) sched.handleEvent(cpu);
    }
}

fn syncToAudio(cpu: *const Arm7tdmi) void {
    const stream = cpu.bus.apu.stream;
    const min_sample_count = 0x800;

    // Busy Loop while we wait for the Audio system to catch up
    while (SDL.SDL_AudioStreamAvailable(stream) > (@sizeOf(u16) * 2) * min_sample_count) {}
}

pub fn runUnsynchronized(quit: *Atomic(bool), sched: *Scheduler, cpu: *Arm7tdmi, fps: ?*FpsTracker) void {
    log.info("Emulation thread w/out video sync", .{});

    if (fps) |tracker| {
        log.info("FPS Tracking Enabled", .{});

        while (!quit.load(.SeqCst)) {
            runFrame(sched, cpu);
            if (sync_audio) syncToAudio(cpu);

            tracker.tick();
        }
    } else {
        while (!quit.load(.SeqCst)) {
            runFrame(sched, cpu);
            if (sync_audio) syncToAudio(cpu);
        }
    }
}

pub fn runSynchronized(quit: *Atomic(bool), sched: *Scheduler, cpu: *Arm7tdmi, fps: ?*FpsTracker) void {
    log.info("Emulation thread w/ video sync", .{});
    var timer = Timer.start() catch unreachable;
    var wake_time: u64 = frame_period;

    if (fps) |tracker| {
        log.info("FPS Tracking Enabled", .{});

        while (!quit.load(.SeqCst)) {
            runFrame(sched, cpu);
            const new_wake_time = syncToVideo(&timer, wake_time);

            // Spin to make up the difference of OS scheduler innacuracies
            // If we happen to also be syncing to audio, we choose to spin on
            // the amount of time needed for audio to catch up rather than
            // our expected wake-up time
            if (sync_audio) syncToAudio(cpu) else spinLoop(&timer, wake_time);
            wake_time = new_wake_time;

            tracker.tick();
        }
    } else {
        while (!quit.load(.SeqCst)) {
            runFrame(sched, cpu);
            const new_wake_time = syncToVideo(&timer, wake_time);
            // see above comment
            if (sync_audio) syncToAudio(cpu) else spinLoop(&timer, wake_time);

            wake_time = new_wake_time;
        }
    }
}

inline fn syncToVideo(timer: *Timer, wake_time: u64) u64 {
    // Use the OS scheduler to put the emulation thread to sleep
    const maybe_recalc_wake_time = sleep(timer, wake_time);

    // If sleep() determined we need to adjust our wake up time, do so
    // otherwise predict our next wake up time according to the frame period
    return if (maybe_recalc_wake_time) |recalc| recalc else wake_time + frame_period;
}

pub fn runBusyLoop(quit: *Atomic(bool), sched: *Scheduler, cpu: *Arm7tdmi) void {
    log.info("Emulation thread with video sync using busy loop", .{});
    var timer = Timer.start() catch unreachable;
    var wake_time: u64 = frame_period;

    while (!quit.load(.SeqCst)) {
        runFrame(sched, cpu);
        spinLoop(&timer, wake_time);

        // Update to the new wake time
        wake_time += frame_period;
    }
}

fn sleep(timer: *Timer, wake_time: u64) ?u64 {
    // const step = std.time.ns_per_ms * 10; // 10ms
    const timestamp = timer.read();

    // ns_late is non zero if we are late.
    const ns_late = timestamp -| wake_time;

    // If we're more than a frame late, skip the rest of this loop
    // Recalculate what our new wake time should be so that we can
    // get "back on track"
    if (ns_late > frame_period) return timestamp + frame_period;
    const sleep_for = frame_period - ns_late;

    // // Employ several sleep calls in periods of 10ms
    // // By doing this the behaviour should average out to be
    // // more consistent
    // const loop_count = sleep_for / step; // How many groups of 10ms

    // var i: usize = 0;
    // while (i < loop_count) : (i += 1) std.time.sleep(step);

    std.time.sleep(sleep_for);

    return null;
}

fn spinLoop(timer: *Timer, wake_time: u64) void {
    while (true) if (timer.read() > wake_time) break;
}
