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

    pub fn deinit(self: *@This()) void {
        self.queue.deinit();
    }

    pub fn handleEvent(self: *@This(), _: *Arm7tdmi, bus: *Bus) void {
        const should_handle = if (self.queue.peek()) |e| self.tick >= e.tick else false;

        if (should_handle) {
            const event = self.queue.remove();

            switch (event.kind) {
                .HeatDeath => {
                    std.debug.panic("[Scheduler] Somehow, a u64 overflowed", .{});
                },
                .HBlank => {
                    std.log.debug("[Scheduler] tick {}: Hblank", .{self.tick});

                    // We've reached the end of a scanline
                    const scanline = bus.io.vcount.scanline.read();
                    bus.io.vcount.scanline.write(scanline + 1);

                    bus.io.dispstat.hblank.set();

                    if (scanline < 160) {
                        self.push(.{ .kind = .Visible, .tick = self.tick + (68 * 4) });
                    } else {
                        self.push(.{ .kind = .VBlank, .tick = self.tick + (68 * 4) });
                    }
                },
                .Visible => {
                    std.log.debug("[Scheduler] tick {}: Visible", .{self.tick});

                    // Beginning of a Scanline
                    bus.io.dispstat.hblank.unset();
                    bus.io.dispstat.vblank.unset();

                    self.push(.{ .kind = .HBlank, .tick = self.tick + (240 * 4) });
                },
                .VBlank => {
                    std.log.debug("[Scheduler] tick {}: VBlank", .{self.tick});

                    // Beginning of a Scanline, not visible though
                    bus.io.dispstat.hblank.unset();
                    bus.io.dispstat.vblank.set();

                    const scanline = bus.io.vcount.scanline.read();
                    bus.io.vcount.scanline.write(scanline + 1);

                    if (scanline < 227) {
                        // Another Vblank Scanline
                        self.push(.{ .kind = .VBlank, .tick = self.tick + 68 * (308 * 4) });
                    } else {
                        bus.io.vcount.scanline.write(0); // Reset Scanline
                        self.push(.{ .kind = .Visible, .tick = self.tick + 68 * (308 * 4) });
                    }
                },
            }
        }
    }

    pub inline fn push(self: *@This(), event: Event) void {
        self.queue.add(event) catch unreachable;
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
    HBlank,
    VBlank,
    Visible,
};
