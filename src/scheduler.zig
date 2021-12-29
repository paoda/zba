const std = @import("std");
const ARM7TDMI = @import("cpu.zig").ARM7TDMI;
const Bus = @import("bus.zig").Bus;

const Order = std.math.Order;
const PriorityQueue = std.PriorityQueue;
const Allocator = std.mem.Allocator;

pub const Scheduler = struct {
    tick: u64,
    queue: PriorityQueue(Event, void, lessThan),

    pub fn new(alloc: Allocator) @This() {
        var scheduler = Scheduler{ .tick = 0, .queue = PriorityQueue(Event, void, lessThan).init(alloc, {}) };

        scheduler.queue.add(.{
            .kind = EventKind.HeatDeath,
            .tick = std.math.maxInt(u64),
        }) catch unreachable;

        return scheduler;
    }

    pub fn handleEvent(self: *@This(), _: *ARM7TDMI, _: *Bus) void {
        const should_handle = if (self.queue.peek()) |e| self.tick >= e.tick else false;

        if (should_handle) {
            const event = self.queue.remove();

            switch (event.kind) {
                .HeatDeath => {
                    std.debug.panic("Somehow, a u64 overflowed", .{});
                },
            }
        }
    }

    pub inline fn nextTimestamp(self: *@This()) u64 {
        if (self.queue.peek()) |e| {
            return e.tick;
        } else unreachable;
    }
};

pub const Event = struct {
    kind: EventKind,
    tick: u64,
};

fn lessThan(context: void, a: Event, b: Event) Order {
    _ = context;
    return std.math.order(a.tick, b.tick);
}

pub const EventKind = enum {
    HeatDeath,
};
