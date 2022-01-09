const std = @import("std");

const Bus = @import("Bus.zig");
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

    pub fn deinit(self: @This()) void {
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
                    // The End of a Hblank
                    const scanline = bus.io.vcount.scanline.read();
                    const new_scanline = scanline + 1;

                    // TODO: Should this be done @ end of Draw instead of end of Hblank?
                    bus.ppu.drawScanline(&bus.io);

                    bus.io.vcount.scanline.write(new_scanline);
                    bus.io.dispstat.hblank.unset();

                    if (new_scanline < 160) {
                        // Transitioning to another Draw
                        self.push(.{ .kind = .Draw, .tick = self.tick + (240 * 4) });
                    } else {
                        // Transitioning to a Vblank
                        bus.io.dispstat.vblank.set();
                        self.push(.{ .kind = .VBlank, .tick = self.tick + (308 * 4) });
                    }
                },
                .Draw => {
                    // The end of a Draw

                    // Transitioning to a Hblank
                    bus.io.dispstat.hblank.set();
                    self.push(.{ .kind = .HBlank, .tick = self.tick + (68 * 4) });
                },
                .VBlank => {
                    // The end of a Vblank

                    const scanline = bus.io.vcount.scanline.read();
                    const new_scanline = scanline + 1;
                    bus.io.vcount.scanline.write(new_scanline);

                    if (new_scanline < 228) {
                        // Transition to another Vblank
                        self.push(.{ .kind = .VBlank, .tick = self.tick + (308 * 4) });
                    } else {
                        // Transition to another Draw
                        bus.io.vcount.scanline.write(0); // Reset Scanline

                        bus.io.dispstat.vblank.unset();
                        self.push(.{ .kind = .Draw, .tick = self.tick + (240 * 4) });
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
    Draw,
};
