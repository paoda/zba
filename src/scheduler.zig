const std = @import("std");

const Bus = @import("Bus.zig");
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const Order = std.math.Order;
const PriorityQueue = std.PriorityQueue;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Scheduler);

pub const Scheduler = struct {
    const Self = @This();

    tick: u64,
    queue: PriorityQueue(Event, void, lessThan),

    pub fn init(alloc: Allocator) Self {
        var sched = Self{ .tick = 0, .queue = PriorityQueue(Event, void, lessThan).init(alloc, {}) };
        sched.push(.HeatDeath, std.math.maxInt(u64));

        return sched;
    }

    pub fn deinit(self: Self) void {
        self.queue.deinit();
    }

    pub inline fn now(self: *const Self) u64 {
        return self.tick;
    }

    pub fn handleEvent(self: *Self, cpu: *Arm7tdmi) void {
        if (self.queue.removeOrNull()) |event| {
            const late = self.tick - event.tick;

            switch (event.kind) {
                .HeatDeath => {
                    log.err("A u64 overflowered. This *actually* should never happen.", .{});
                    unreachable;
                },
                .Draw => {
                    // The end of a VDraw
                    cpu.bus.ppu.drawScanline();
                    cpu.bus.ppu.handleHDrawEnd(cpu, late);
                },
                .TimerOverflow => |id| {
                    switch (id) {
                        0 => cpu.bus.tim._0.handleOverflow(cpu, late),
                        1 => cpu.bus.tim._1.handleOverflow(cpu, late),
                        2 => cpu.bus.tim._2.handleOverflow(cpu, late),
                        3 => cpu.bus.tim._3.handleOverflow(cpu, late),
                    }
                },
                .ApuChannel => |id| {
                    switch (id) {
                        0 => cpu.bus.apu.ch1.channelTimerOverflow(late),
                        1 => cpu.bus.apu.ch2.channelTimerOverflow(late),
                        else => {},
                    }
                },
                .FrameSequencer => cpu.bus.apu.tickFrameSequencer(late),
                .SampleAudio => cpu.bus.apu.sampleAudio(late),
                .HBlank => cpu.bus.ppu.handleHBlankEnd(cpu, late), // The end of a HBlank
                .VBlank => cpu.bus.ppu.handleHDrawEnd(cpu, late), // The end of a VBlank
            }
        }
    }

    /// Removes the **first** scheduled event of type `needle`
    pub fn removeScheduledEvent(self: *Self, needle: EventKind) void {
        var it = self.queue.iterator();

        var i: usize = 0;
        while (it.next()) |event| : (i += 1) {
            if (std.meta.eql(event.kind, needle)) {

                // This invalidates the iterator
                _ = self.queue.removeIndex(i);

                // Since removing something from the PQ invalidates the iterator,
                // this implementation can safely only remove the first instance of
                // a Scheduled Event. Exit Early
                break;
            }
        }
    }

    pub fn push(self: *Self, kind: EventKind, end: u64) void {
        self.queue.add(.{ .kind = kind, .tick = end }) catch unreachable;
    }

    pub fn nextTimestamp(self: *Self) u64 {
        if (self.queue.peek()) |e| return e.tick;

        unreachable; // There's always the HeatDeath event scheduled
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
};
