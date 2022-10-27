const std = @import("std");
const SDL = @import("sdl2");
const config = @import("../config.zig");

const Bus = @import("Bus.zig");
const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const FpsTracker = @import("../util.zig").FpsTracker;
const FilePaths = @import("../util.zig").FilePaths;

const Timer = std.time.Timer;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;
const Allocator = std.mem.Allocator;

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
};

pub fn run(quit: *Atomic(bool), scheduler: *Scheduler, cpu: *Arm7tdmi, tracker: *FpsTracker) void {
    const audio_sync = config.config().guest.audio_sync and !config.config().host.mute;
    if (audio_sync) log.info("Audio sync enabled", .{});

    if (config.config().guest.video_sync) {
        inner(.LimitedFPS, audio_sync, quit, scheduler, cpu, tracker);
    } else {
        inner(.UnlimitedFPS, audio_sync, quit, scheduler, cpu, tracker);
    }
}

fn inner(comptime kind: RunKind, audio_sync: bool, quit: *Atomic(bool), scheduler: *Scheduler, cpu: *Arm7tdmi, tracker: ?*FpsTracker) void {
    if (kind == .UnlimitedFPS or kind == .LimitedFPS) {
        std.debug.assert(tracker != null);
        log.info("FPS tracking enabled", .{});
    }

    switch (kind) {
        .Unlimited, .UnlimitedFPS => {
            log.info("Emulation w/out video sync", .{});

            while (!quit.load(.SeqCst)) {
                runFrame(scheduler, cpu);
                audioSync(audio_sync, cpu.bus.apu.stream, &cpu.bus.apu.is_buffer_full);

                if (kind == .UnlimitedFPS) tracker.?.tick();
            }
        },
        .Limited, .LimitedFPS => {
            log.info("Emulation w/ video sync", .{});
            var timer = Timer.start() catch @panic("failed to initalize std.timer.Timer");
            var wake_time: u64 = frame_period;

            while (!quit.load(.SeqCst)) {
                runFrame(scheduler, cpu);
                const new_wake_time = videoSync(&timer, wake_time);

                // Spin to make up the difference of OS scheduler innacuracies
                // If we happen to also be syncing to audio, we choose to spin on
                // the amount of time needed for audio to catch up rather than
                // our expected wake-up time

                audioSync(audio_sync, cpu.bus.apu.stream, &cpu.bus.apu.is_buffer_full);
                if (!audio_sync) spinLoop(&timer, wake_time);
                wake_time = new_wake_time;

                if (kind == .LimitedFPS) tracker.?.tick();
            }
        },
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

fn audioSync(audio_sync: bool, stream: *SDL.SDL_AudioStream, is_buffer_full: *bool) void {
    const sample_size = 2 * @sizeOf(u16);
    const max_buf_size: c_int = 0x400;

    // Determine whether the APU is busy right at this moment
    var still_full: bool = SDL.SDL_AudioStreamAvailable(stream) > sample_size * if (is_buffer_full.*) max_buf_size >> 1 else max_buf_size;
    defer is_buffer_full.* = still_full; // Update APU Busy status right before exiting scope

    // If Busy is false, there's no need to sync here
    if (!still_full) return;

    while (true) {
        still_full = SDL.SDL_AudioStreamAvailable(stream) > sample_size * max_buf_size >> 1;
        if (!audio_sync or !still_full) break;
    }
}

fn videoSync(timer: *Timer, wake_time: u64) u64 {
    // Use the OS scheduler to put the emulation thread to sleep
    const recalculated = sleep(timer, wake_time);

    // If sleep() determined we need to adjust our wake up time, do so
    // otherwise predict our next wake up time according to the frame period
    return recalculated orelse wake_time + frame_period;
}

// TODO: Better sleep impl?
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
