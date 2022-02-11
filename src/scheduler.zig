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

    pub fn handleEvent(self: *Self, _: *Arm7tdmi, bus: *Bus) void {
        const should_handle = if (self.queue.peek()) |e| self.tick >= e.tick else false;

        if (should_handle) {
            const event = self.queue.remove();
            // log.debug("Handle {} @ tick = {}", .{ event.kind, self.tick });

            switch (event.kind) {
                .HeatDeath => {
                    std.debug.panic("[Scheduler] Somehow, a u64 overflowed", .{});
                },
                .HBlank => {
                    // The End of a Hblank (During Draw or Vblank)
                    const old_scanline = bus.io.vcount.scanline.read();
                    const scanline = (old_scanline + 1) % 228;

                    bus.io.vcount.scanline.write(scanline);
                    bus.io.dispstat.hblank.unset();

                    if (scanline < 160) {
                        // Transitioning to another Draw
                        self.push(.Draw, self.tick + (240 * 4));
                    } else {
                        // Transitioning to a Vblank
                        if (scanline < 227) bus.io.dispstat.vblank.set() else bus.io.dispstat.vblank.unset();

                        self.push(.VBlank, self.tick + (240 * 4));
                    }
                },
                .Draw => {
                    // The end of a Draw
                    bus.ppu.drawScanline(&bus.io);

                    // Transitioning to a Hblank
                    bus.io.dispstat.hblank.set();
                    self.push(.HBlank, self.tick + (68 * 4));
                },
                .VBlank => {
                    // The end of a Vblank
                    self.push(.HBlank, self.tick + (68 * 4));
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
