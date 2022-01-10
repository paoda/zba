const std = @import("std");

const Bus = @import("Bus.zig");
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const Order = std.math.Order;
const PriorityQueue = std.PriorityQueue;
const Allocator = std.mem.Allocator;

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

    pub fn handleEvent(self: *Self, _: *Arm7tdmi, bus: *Bus) void {
        const should_handle = if (self.queue.peek()) |e| self.tick >= e.tick else false;

        if (should_handle) {
            const event = self.queue.remove();
            // std.log.info("[Scheduler] Handle {} at {} ticks", .{ event.kind, self.tick });

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

                    if (new_scanline < 160) {
                        // Transitioning to another Draw
                        self.push(.Draw, self.tick + (240 * 4));
                    } else {
                        // Transitioning to a Vblank
                        bus.io.dispstat.vblank.set();
                        self.push(.VBlank, self.tick + (308 * 4));
                    }
                },
                .Draw => {
                    // The end of a Draw

                    // Transitioning to a Hblank
                    bus.io.dispstat.hblank.set();
                    self.push(.HBlank, self.tick + (68 * 4));
                },
                .VBlank => {
                    // The end of a Vblank

                    const scanline = bus.io.vcount.scanline.read();
                    const new_scanline = scanline + 1;
                    bus.io.vcount.scanline.write(new_scanline);

                    if (new_scanline == 227) bus.io.dispstat.vblank.unset();

                    if (new_scanline < 228) {
                        // Transition to another Vblank
                        self.push(.VBlank, self.tick + (308 * 4));
                    } else {
                        // Transition to another Draw
                        bus.io.vcount.scanline.write(0); // Reset Scanline

                        // DISPSTAT was disabled on scanline 227
                        self.push(.Draw, self.tick + (240 * 4));
                    }
                },
            }
        }
    }

    pub fn push(self: *Self, kind: EventKind, end: u64) void {
        self.queue.add(.{ .kind = kind, .tick = end }) catch unreachable;
    }

    pub fn nextTimestamp(self: *Self) u64 {
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
