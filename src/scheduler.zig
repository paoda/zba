const std = @import("std");

const pollBlankingDma = @import("bus/dma.zig").pollBlankingDma;

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

    pub fn handleEvent(self: *Self, cpu: *Arm7tdmi, bus: *Bus) void {
        const should_handle = if (self.queue.peek()) |e| self.tick >= e.tick else false;
        const stat = &bus.ppu.dispstat;
        const vcount = &bus.ppu.vcount;
        const irq = &bus.io.irq;

        if (should_handle) {
            const event = self.queue.remove();
            // log.debug("Handle {} @ tick = {}", .{ event.kind, self.tick });

            switch (event.kind) {
                .HeatDeath => {
                    log.err("A u64 overflowered. This *actually* should never happen.", .{});
                    unreachable;
                },
                .HBlank => {
                    // The End of a Hblank (During Draw or Vblank)
                    const old_scanline = vcount.scanline.read();
                    const scanline = (old_scanline + 1) % 228;

                    vcount.scanline.write(scanline);
                    stat.hblank.unset();

                    // Perform Vc == VcT check
                    const coincidence = scanline == stat.vcount_trigger.read();
                    stat.coincidence.write(coincidence);

                    if (coincidence and stat.vcount_irq.read()) {
                        irq.coincidence.set();
                        cpu.handleInterrupt();
                    }

                    if (scanline < 160) {
                        // Transitioning to another Draw
                        self.push(.Draw, self.tick + (240 * 4));
                    } else {
                        // Transitioning to a Vblank
                        if (scanline == 160) {
                            stat.vblank.set();

                            if (stat.vblank_irq.read()) {
                                irq.vblank.set();
                                cpu.handleInterrupt();
                            }

                            // See if Vblank DMA is present and not enabled
                            pollBlankingDma(bus, .VBlank);
                        }

                        if (scanline == 227) stat.vblank.unset();
                        self.push(.VBlank, self.tick + (240 * 4));
                    }
                },
                .Draw => {
                    // The end of a Draw
                    bus.ppu.drawScanline();

                    // Transitioning to a Hblank
                    if (bus.ppu.dispstat.hblank_irq.read()) {
                        bus.io.irq.hblank.set();
                        cpu.handleInterrupt();
                    }

                    // See if Hblank DMA is present and not enabled
                    pollBlankingDma(bus, .HBlank);

                    bus.ppu.dispstat.hblank.set();
                    self.push(.HBlank, self.tick + (68 * 4));
                },
                .VBlank => {
                    // The end of a Vblank

                    // Transitioning to a Hblank
                    if (bus.ppu.dispstat.hblank_irq.read()) {
                        bus.io.irq.hblank.set();
                        cpu.handleInterrupt();
                    }

                    // See if Hblank DMA is present and not enabled
                    pollBlankingDma(bus, .HBlank);

                    bus.ppu.dispstat.hblank.set();
                    self.push(.HBlank, self.tick + (68 * 4));
                },
                .TimerOverflow => |id| {
                    // log.warn("TIM{} Overflowed", .{id});

                    switch (id) {
                        0 => bus.io.tim0.handleOverflow(cpu, &bus.io),
                        1 => bus.io.tim1.handleOverflow(cpu, &bus.io),
                        2 => bus.io.tim2.handleOverflow(cpu, &bus.io),
                        3 => bus.io.tim3.handleOverflow(cpu, &bus.io),
                    }
                },
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

pub const EventKind = union(enum) {
    HeatDeath,
    HBlank,
    VBlank,
    Draw,
    TimerOverflow: u2,
};
