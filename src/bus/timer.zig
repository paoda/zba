const std = @import("std");

const TimerControl = @import("io.zig").TimerControl;
const Io = @import("io.zig").Io;
const Scheduler = @import("../scheduler.zig").Scheduler;
const Event = @import("../scheduler.zig").Event;
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;

const log = std.log.scoped(.Timer);

pub fn Timer(comptime id: u2) type {
    return struct {
        const Self = @This();

        /// Read Only, Internal. Please use self.counter()
        _counter: u16,

        /// Write Only, Internal. Please use self.writeCntLow()
        _reload: u16,

        /// Write Only, Internal. Please use self.WriteCntHigh()
        cnt: TimerControl,

        /// Internal.
        sched: *Scheduler,

        /// Internal
        _start_timestamp: u64,

        pub fn init(sched: *Scheduler) Self {
            return .{
                ._reload = 0,
                ._counter = 0,
                .cnt = .{ .raw = 0x0000 },
                .sched = sched,
                ._start_timestamp = 0,
            };
        }

        pub fn counter(self: *const Self) u16 {
            if (self.cnt.cascade.read())
                return self._counter
            else
                return self._counter +% @truncate(u16, (self.sched.now() - self._start_timestamp) / self.frequency());
        }

        pub fn writeCnt(self: *Self, word: u32) void {
            self.writeCntLow(@truncate(u16, word));
            self.writeCntHigh(@truncate(u16, word >> 16));
        }

        pub fn writeCntLow(self: *Self, halfword: u16) void {
            self._reload = halfword;
        }

        pub fn writeCntHigh(self: *Self, halfword: u16) void {
            const new = TimerControl{ .raw = halfword };

            // If Timer happens to be enabled, It will either be resheduled or disabled
            self.sched.removeScheduledEvent(.{ .TimerOverflow = id });

            if (!self.cnt.enabled.read() and new.enabled.read()) {
                // Reload on Rising edge
                self._counter = self._reload;

                if (!new.cascade.read()) self.scheduleOverflow();
            }

            self.cnt.raw = halfword;
        }

        pub fn handleOverflow(self: *Self, cpu: *Arm7tdmi, io: *Io) void {
            // Fire IRQ if enabled
            if (self.cnt.irq.read()) {
                switch (id) {
                    0 => io.irq.tim0_overflow.set(),
                    1 => io.irq.tim1_overflow.set(),
                    2 => io.irq.tim2_overflow.set(),
                    3 => io.irq.tim3_overflow.set(),
                }

                cpu.handleInterrupt();
            }

            // Perform Cascade Behaviour
            switch (id) {
                0 => if (io.tim1.cnt.cascade.read()) {
                    io.tim1._counter +%= 1;

                    if (io.tim1._counter == 0)
                        io.tim1.handleOverflow(cpu, io);
                },
                1 => if (io.tim2.cnt.cascade.read()) {
                    io.tim2._counter +%= 1;

                    if (io.tim2._counter == 0)
                        io.tim2.handleOverflow(cpu, io);
                },
                2 => if (io.tim3.cnt.cascade.read()) {
                    io.tim3._counter +%= 1;

                    if (io.tim3._counter == 0)
                        io.tim3.handleOverflow(cpu, io);
                },
                3 => {}, // There is no Timer for TIM3 to "cascade" to,
            }

            // Reschedule Timer if we're not cascading
            if (!self.cnt.cascade.read()) {
                self._counter = self._reload;
                self.scheduleOverflow();
            }
        }

        fn scheduleOverflow(self: *Self) void {
            const when = (@as(u64, 0x10000) - self._counter) * self.frequency();

            self._start_timestamp = self.sched.now();
            self.sched.push(.{ .TimerOverflow = id }, self.sched.now() + when);
        }

        fn frequency(self: *const Self) u16 {
            return switch (self.cnt.frequency.read()) {
                0 => 1,
                1 => 64,
                2 => 256,
                3 => 1024,
            };
        }
    };
}
