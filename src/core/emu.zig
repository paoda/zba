const std = @import("std");
const SDL = @import("sdl2");
const config = @import("../config.zig");

const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("arm32").Arm7tdmi;
const Bus = @import("Bus.zig");
const Tracker = @import("../util.zig").FpsTracker;
const Channel = @import("../util.zig").Queue;

const stepDmaTransfer = @import("cpu_util.zig").stepDmaTransfer;
const isHalted = @import("cpu_util.zig").isHalted;

const Timer = std.time.Timer;

pub const Synchro = struct {
    const AtomicBool = std.atomic.Value(bool);

    // FIXME: This Enum ends up being really LARGE!!!
    pub const Message = union(enum) {
        rom_path: [std.fs.MAX_PATH_BYTES]u8,
        bios_path: [std.fs.MAX_PATH_BYTES]u8,
        restart: void,
    };

    paused: AtomicBool = AtomicBool.init(true), // FIXME: can ui_busy and paused be the same?
    should_quit: AtomicBool = AtomicBool.init(false),

    ch: Channel(Message),

    pub fn init(allocator: std.mem.Allocator) !@This() {
        const msg_buf = try allocator.alloc(Message, 1);
        return .{ .ch = Channel(Message).init(msg_buf) };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.ch.inner.buf);
        self.* = undefined;
    }
};

/// 4 Cycles in 1 dot
const cycles_per_dot = 4;

/// The GBA draws 228 Horizontal which each consist 308 dots
/// (note: not all lines are visible)
const cycles_per_frame = 228 * (308 * cycles_per_dot); //280896

/// The GBA ARM7TDMI runs at 2^24 Hz
const clock_rate = 1 << 24; // 16.78MHz

/// The # of nanoseconds a frame should take
const frame_period = (std.time.ns_per_s * cycles_per_frame) / clock_rate;

/// Exact Value:  59.7275005696Hz
/// The inverse of the frame period
pub const frame_rate: f64 = @as(f64, @floatFromInt(clock_rate)) / cycles_per_frame;

const log = std.log.scoped(.Emulation);

const RunKind = enum {
    Unlimited,
    UnlimitedFPS,
    Limited,
    LimitedFPS,
};

pub fn run(cpu: *Arm7tdmi, scheduler: *Scheduler, tracker: *Tracker, sync: *Synchro) void {
    const audio_sync = config.config().guest.audio_sync and !config.config().host.mute;
    if (audio_sync) log.info("Audio sync enabled", .{});

    if (config.config().guest.video_sync) {
        inner(.LimitedFPS, audio_sync, cpu, scheduler, tracker, sync);
    } else {
        inner(.UnlimitedFPS, audio_sync, cpu, scheduler, tracker, sync);
    }
}

fn inner(comptime kind: RunKind, audio_sync: bool, cpu: *Arm7tdmi, scheduler: *Scheduler, tracker: ?*Tracker, sync: *Synchro) void {
    if (kind == .UnlimitedFPS or kind == .LimitedFPS) {
        std.debug.assert(tracker != null);
        log.info("FPS tracking enabled", .{});
    }

    const bus_ptr: *Bus = @ptrCast(@alignCast(cpu.bus.ptr));

    // FIXME: audioSync accesses emulator state without any guarantees

    switch (kind) {
        .Unlimited, .UnlimitedFPS => {
            log.info("Emulation w/out video sync", .{});

            while (!sync.should_quit.load(.monotonic)) {
                handleChannel(cpu, &sync.ch);
                if (sync.paused.load(.monotonic)) continue;

                runFrame(scheduler, cpu);
                audioSync(audio_sync, bus_ptr.apu.stream, &bus_ptr.apu.is_buffer_full);

                if (kind == .UnlimitedFPS) tracker.?.tick();
            }
        },
        .Limited, .LimitedFPS => {
            log.info("Emulation w/ video sync", .{});
            var timer = Timer.start() catch @panic("failed to initalize std.timer.Timer");
            var wake_time: u64 = frame_period;

            while (!sync.should_quit.load(.monotonic)) {
                handleChannel(cpu, &sync.ch);
                if (sync.paused.load(.monotonic)) continue;

                runFrame(scheduler, cpu);
                const new_wake_time = videoSync(&timer, wake_time);

                // Spin to make up the difference of OS scheduler innacuracies
                // If we happen to also be syncing to audio, we choose to spin on
                // the amount of time needed for audio to catch up rather than
                // our expected wake-up time

                audioSync(audio_sync, bus_ptr.apu.stream, &bus_ptr.apu.is_buffer_full);
                if (!audio_sync) spinLoop(&timer, wake_time);
                wake_time = new_wake_time;

                if (kind == .LimitedFPS) tracker.?.tick();
            }
        },
    }
}

inline fn handleChannel(cpu: *Arm7tdmi, channel: *Channel(Synchro.Message)) void {
    const message = channel.pop() orelse return;

    switch (message) {
        .rom_path => |path_buf| {
            const path = std.mem.sliceTo(&path_buf, 0);
            replaceGamepak(cpu, path) catch |e| log.err("failed to replace GamePak: {}", .{e});
        },
        .bios_path => |path_buf| {
            const path = std.mem.sliceTo(&path_buf, 0);
            replaceBios(cpu, path) catch |e| log.err("failed to replace BIOS: {}", .{e});
        },
        .restart => reset(cpu),
    }
}

pub fn runFrame(sched: *Scheduler, cpu: *Arm7tdmi) void {
    const frame_end = sched.tick + cycles_per_frame;

    while (sched.tick < frame_end) {
        if (!stepDmaTransfer(cpu)) {
            if (isHalted(cpu)) {
                // Fast-forward to next Event
                sched.tick = sched.nextTimestamp();
            } else {
                cpu.step();
            }
        }

        if (sched.tick >= sched.nextTimestamp()) sched.handleEvent(cpu);
    }
}

fn audioSync(audio_sync: bool, stream: *SDL.SDL_AudioStream, is_buffer_full: *bool) void {
    comptime std.debug.assert(@import("../platform.zig").sample_format == SDL.AUDIO_U16);
    const sample_size = 2 * @sizeOf(u16);
    const max_buf_size: c_int = 0x400;

    // Determine whether the APU is busy right at this moment
    var still_full: bool = SDL.SDL_AudioStreamAvailable(stream) > sample_size * if (is_buffer_full.*) max_buf_size >> 1 else max_buf_size;
    defer is_buffer_full.* = still_full; // Update APU Busy status right before exiting scope

    // If Busy is false, there's no need to sync here
    if (!still_full) return;

    // TODO: Refactor!!!!
    // while (SDL.SDL_AudioStreamAvailable(stream) > sample_size * max_buf_size >> 1)
    //     std.atomic.spinLoopHint();

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
    const timestamp = timer.read();

    // ns_late is non zero if we are late.
    var ns_late = timestamp -| wake_time;

    // If we're more than a frame late, skip the rest of this loop
    // Recalculate what our new wake time should be so that we can
    // get "back on track"
    if (ns_late > frame_period) return timestamp + frame_period;
    const sleep_for = frame_period - ns_late;

    const step = 2 * std.time.ns_per_ms; // Granularity of 2ms
    const times = sleep_for / step;

    for (0..times) |_| {
        std.time.sleep(step);

        // Upon wakeup, check to see if this particular sleep was longer than expected
        // if so we should exit early, but probably not skip a whole frame period
        ns_late = timer.read() -| wake_time;
        if (ns_late > frame_period) return null;
    }

    return null;
}

fn spinLoop(timer: *Timer, wake_time: u64) void {
    while (timer.read() < wake_time)
        std.atomic.spinLoopHint();
}

pub const EmuThing = struct {
    const Self = @This();
    const Interface = @import("gdbstub").Emulator;
    const Allocator = std.mem.Allocator;

    pub const target =
        \\<target version="1.0">
        \\    <architecture>armv4t</architecture>
        \\    <feature name="org.gnu.gdb.arm.core">
        \\        <reg name="r0" bitsize="32" type="uint32"/>
        \\        <reg name="r1" bitsize="32" type="uint32"/>
        \\        <reg name="r2" bitsize="32" type="uint32"/>
        \\        <reg name="r3" bitsize="32" type="uint32"/>
        \\        <reg name="r4" bitsize="32" type="uint32"/>
        \\        <reg name="r5" bitsize="32" type="uint32"/>
        \\        <reg name="r6" bitsize="32" type="uint32"/>
        \\        <reg name="r7" bitsize="32" type="uint32"/>
        \\        <reg name="r8" bitsize="32" type="uint32"/>
        \\        <reg name="r9" bitsize="32" type="uint32"/>
        \\        <reg name="r10" bitsize="32" type="uint32"/>
        \\        <reg name="r11" bitsize="32" type="uint32"/>
        \\        <reg name="r12" bitsize="32" type="uint32"/>
        \\        <reg name="sp" bitsize="32" type="data_ptr"/>
        \\        <reg name="lr" bitsize="32"/>
        \\        <reg name="pc" bitsize="32" type="code_ptr"/>
        \\
        \\        <reg name="cpsr" bitsize="32" regnum="25"/>
        \\    </feature>
        \\</target>
    ;

    // Game Pak SRAM isn't included
    // TODO: Can i be more specific here?
    pub const map =
        \\ <memory-map version="1.0">
        \\     <memory type="rom" start="0x00000000" length="0x00004000"/>
        \\     <memory type="ram" start="0x02000000" length="0x00040000"/>
        \\     <memory type="ram" start="0x03000000" length="0x00008000"/>
        \\     <memory type="ram" start="0x04000000" length="0x00000400"/>
        \\     <memory type="ram" start="0x05000000" length="0x00000400"/>
        \\     <memory type="ram" start="0x06000000" length="0x00018000"/>
        \\     <memory type="ram" start="0x07000000" length="0x00000400"/>
        \\     <memory type="rom" start="0x08000000" length="0x02000000"/>
        \\     <memory type="rom" start="0x0A000000" length="0x02000000"/>
        \\     <memory type="rom" start="0x0C000000" length="0x02000000"/>
        \\ </memory-map>
    ;

    cpu: *Arm7tdmi,
    scheduler: *Scheduler,

    pub fn init(cpu: *Arm7tdmi, scheduler: *Scheduler) Self {
        return .{ .cpu = cpu, .scheduler = scheduler };
    }

    pub fn interface(self: *Self, allocator: Allocator) Interface {
        return Interface.init(allocator, self);
    }

    pub fn read(self: *const Self, addr: u32) u8 {
        return self.cpu.bus.dbgRead(u8, addr);
    }

    pub fn write(self: *Self, addr: u32, value: u8) void {
        self.cpu.bus.dbgWrite(u8, addr, value);
    }

    pub fn registers(self: *const Self) *[16]u32 {
        return &self.cpu.r;
    }

    pub fn cpsr(self: *const Self) u32 {
        return self.cpu.cpsr.raw;
    }

    pub fn step(self: *Self) void {
        const cpu = self.cpu;
        const sched = self.scheduler;

        // Is true when we have executed one (1) instruction
        var did_step: bool = false;

        // TODO: How can I make it easier to keep this in lock-step with runFrame?
        while (!did_step) {
            if (!stepDmaTransfer(cpu)) {
                if (isHalted(cpu)) {
                    // Fast-forward to next Event
                    sched.tick = sched.queue.peek().?.tick;
                } else {
                    cpu.step();
                    did_step = true;
                }
            }

            if (sched.tick >= sched.nextTimestamp()) sched.handleEvent(cpu);
        }
    }
};

fn reset(cpu: *Arm7tdmi) void {
    // @breakpoint();
    cpu.sched.reset(); // Yes this is order sensitive, see the PPU reset for why
    cpu.bus.reset();
    cpu.reset();
}

fn replaceGamepak(cpu: *Arm7tdmi, file_path: []const u8) !void {
    const bus_ptr: *Bus = @ptrCast(@alignCast(cpu.bus.ptr));

    try bus_ptr.replaceGamepak(file_path);
    reset(cpu);
}

fn replaceBios(cpu: *Arm7tdmi, file_path: []const u8) !void {
    const bus_ptr: *Bus = @ptrCast(@alignCast(cpu.bus.ptr));

    const allocator = bus_ptr.bios.allocator;
    const bios_len = 0x4000;

    bus_ptr.bios.buf = try allocator.alloc(u8, bios_len);
    try bus_ptr.bios.load(file_path);
}
