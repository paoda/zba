const std = @import("std");

const Arm7tdmi = @import("arm32").Arm7tdmi;
const Bus = @import("Bus.zig");
const Clock = @import("bus/gpio.zig").Clock;

const Order = std.math.Order;
const PriorityQueue = std.PriorityQueue;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Scheduler);

pub const Scheduler = struct {
    const Self = @This();

    tick: u64 = 0,
    queue: PriorityQueue(Event, void, lessThan),

    pub fn init(allocator: Allocator) Self {
        var sched = Self{ .queue = PriorityQueue(Event, void, lessThan).init(allocator, {}) };
        sched.queue.add(.{ .kind = .HeatDeath, .tick = std.math.maxInt(u64) }) catch unreachable;

        return sched;
    }

    pub fn deinit(self: *Self) void {
        self.queue.deinit();
        self.* = undefined;
    }

    pub fn reset(self: *Self) void {
        // `std.PriorityQueue` provides no reset function, so we will just create a new one
        const allocator = self.queue.allocator;
        self.queue.deinit();

        var new_queue = PriorityQueue(Event, void, lessThan).init(allocator, {});
        new_queue.add(.{ .kind = .HeatDeath, .tick = std.math.maxInt(u64) }) catch unreachable;

        self.* = .{ .queue = new_queue };
    }

    pub inline fn now(self: *const Self) u64 {
        return self.tick;
    }

    pub fn handleEvent(self: *Self, cpu: *Arm7tdmi) void {
        const event = self.queue.remove();
        const late = self.tick - event.tick;

        const bus_ptr: *Bus = @ptrCast(@alignCast(cpu.bus.ptr));

        switch (event.kind) {
            .HeatDeath => {
                log.err("u64 overflow. This *actually* should never happen.", .{});
                unreachable;
            },
            .Draw => {
                // The end of a VDraw
                bus_ptr.ppu.drawScanline();
                bus_ptr.ppu.onHdrawEnd(cpu, late);
            },
            .TimerOverflow => |id| {
                switch (id) {
                    inline 0...3 => |idx| bus_ptr.tim[idx].onTimerExpire(cpu, late),
                }
            },
            .ApuChannel => |id| {
                switch (id) {
                    0 => bus_ptr.apu.ch1.onToneSweepEvent(late),
                    1 => bus_ptr.apu.ch2.onToneEvent(late),
                    2 => bus_ptr.apu.ch3.onWaveEvent(late),
                    3 => bus_ptr.apu.ch4.onNoiseEvent(late),
                }
            },
            .RealTimeClock => {
                const device = &bus_ptr.pak.gpio.device;
                if (device.kind != .Rtc or device.ptr == null) return;

                const clock: *Clock = @ptrCast(@alignCast(device.ptr.?));
                clock.onClockUpdate(late);
            },
            .FrameSequencer => bus_ptr.apu.onSequencerTick(late),
            .SampleAudio => bus_ptr.apu.sampleAudio(late),
            .HBlank => bus_ptr.ppu.onHblankEnd(cpu, late), // The end of a HBlank
            .VBlank => bus_ptr.ppu.onHdrawEnd(cpu, late), // The end of a VBlank
        }
    }

    /// Removes the **first** scheduled event of type `needle`
    pub fn removeScheduledEvent(self: *Self, needle: EventKind) void {
        for (self.queue.items, 0..) |event, i| {
            if (std.meta.eql(event.kind, needle)) {

                // invalidates the slice we're iterating over
                _ = self.queue.removeIndex(i);

                log.debug("Removed {?}@{}", .{ event.kind, event.tick });
                break;
            }
        }
    }

    pub fn push(self: *Self, kind: EventKind, end: u64) void {
        self.queue.add(.{ .kind = kind, .tick = self.now() + end }) catch unreachable;
    }

    pub inline fn nextTimestamp(self: *const Self) u64 {
        @setRuntimeSafety(false);

        // Typically you'd use PriorityQueue.peek here, but there's always at least a HeatDeath
        // event in the PQ so we can just do this instead. Should be faster in ReleaseSafe
        return self.queue.items[0].tick;
    }
};

pub const Event = struct {
    kind: EventKind,
    tick: u64,
};

fn lessThan(_: void, a: Event, b: Event) Order {
    return std.math.order(a.tick, b.tick);
}

pub const EventKind = union(enum) {
    HeatDeath,
    HBlank,
    VBlank,
    Draw,
    TimerOverflow: u2,
    SampleAudio,
    FrameSequencer,
    ApuChannel: u2,
    RealTimeClock,
};
