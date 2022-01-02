const std = @import("std");

const Bus = @import("bus.zig").Bus;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Order = std.math.Order;
const PriorityQueue = std.PriorityQueue;
const Allocator = std.mem.Allocator;

pub const Scheduler = struct {
    tick: u64,
    queue: PriorityQueue(Event, void, lessThan),

    pub fn init(alloc: Allocator) @This() {
        var scheduler = Scheduler{ .tick = 0, .queue = PriorityQueue(Event, void, lessThan).init(alloc, {}) };

        scheduler.queue.add(.{
            .kind = EventKind.HeatDeath,
            .tick = std.math.maxInt(u64),
        }) catch unreachable;

        return scheduler;
    }

    pub fn handleEvent(self: *@This(), _: *Arm7tdmi, _: *Bus) void {
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

fn lessThan(_: void, a: Event, b: Event) Order {
    return std.math.order(a.tick, b.tick);
}

pub const EventKind = enum {
    HeatDeath,
};
