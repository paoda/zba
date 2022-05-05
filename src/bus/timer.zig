const std = @import("std");

const TimerControl = @import("io.zig").TimerControl;
const Io = @import("io.zig").Io;
const Scheduler = @import("../scheduler.zig").Scheduler;
const Event = @import("../scheduler.zig").Event;
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;

pub const TimerTuple = std.meta.Tuple(&[_]type{ Timer(0), Timer(1), Timer(2), Timer(3) });
const log = std.log.scoped(.Timer);

pub fn create(sched: *Scheduler) TimerTuple {
    return .{ Timer(0).init(sched), Timer(1).init(sched), Timer(2).init(sched), Timer(3).init(sched) };
}

fn Timer(comptime id: u2) type {
    return struct {
        const Self = @This();

        /// Read Only, Internal. Please use self.counter()
        _counter: u16,

        /// Write Only, Internal. Please use self.setReload()
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
            if (self.cnt.cascade.read() or !self.cnt.enabled.read()) return self._counter;

            return self._counter +% @truncate(u16, (self.sched.now() - self._start_timestamp) / self.frequency());
        }

        pub fn writeCnt(self: *Self, word: u32) void {
            self.setReload(@truncate(u16, word));
            self.writeCntHigh(@truncate(u16, word >> 16));
        }

        pub fn setReload(self: *Self, halfword: u16) void {
            self._reload = halfword;
        }

        pub fn writeCntHigh(self: *Self, halfword: u16) void {
            const new = TimerControl{ .raw = halfword };

            // If Timer happens to be enabled, It will either be resheduled or disabled
            self.sched.removeScheduledEvent(.{ .TimerOverflow = id });

            if (self.cnt.enabled.read() and (new.cascade.read() or !new.enabled.read())) {
                // Either through the cascade bit or the enable bit, the timer has effectively been disabled
                // The Counter should hold whatever value it should have been at when it was disabled
                self._counter +%= @truncate(u16, (self.sched.now() - self._start_timestamp) / self.frequency());
            }

            // The counter is only reloaded on the rising edge of the enable bit
            if (!self.cnt.enabled.read() and new.enabled.read()) self._counter = self._reload;

            // If Timer is enabled and we're not cascading, we need to schedule an overflow event
            if (new.enabled.read() and !new.cascade.read()) self.scheduleOverflow(0);

            self.cnt.raw = halfword;
        }

        pub fn handleOverflow(self: *Self, cpu: *Arm7tdmi, late: u64) void {
            // Fire IRQ if enabled
            const io = &cpu.bus.io;

            if (self.cnt.irq.read()) {
                switch (id) {
                    0 => io.irq.tim0_overflow.set(),
                    1 => io.irq.tim1_overflow.set(),
                    2 => io.irq.tim2_overflow.set(),
                    3 => io.irq.tim3_overflow.set(),
                }

                cpu.handleInterrupt();
            }

            // DMA Sound Things
            if (id == 0 or id == 1) {
                cpu.bus.apu.handleTimerOverflow(cpu, id);
            }

            // Perform Cascade Behaviour
            switch (id) {
                0 => if (cpu.bus.tim[1].cnt.cascade.read()) {
                    cpu.bus.tim[1]._counter +%= 1;
                    if (cpu.bus.tim[1]._counter == 0) cpu.bus.tim[1].handleOverflow(cpu, late);
                },
                1 => if (cpu.bus.tim[2].cnt.cascade.read()) {
                    cpu.bus.tim[2]._counter +%= 1;
                    if (cpu.bus.tim[2]._counter == 0) cpu.bus.tim[2].handleOverflow(cpu, late);
                },
                2 => if (cpu.bus.tim[3].cnt.cascade.read()) {
                    cpu.bus.tim[3]._counter +%= 1;
                    if (cpu.bus.tim[3]._counter == 0) cpu.bus.tim[3].handleOverflow(cpu, late);
                },
                3 => {}, // There is no Timer for TIM3 to "cascade" to,
            }

            // Reschedule Timer if we're not cascading
            if (!self.cnt.cascade.read()) {
                self._counter = self._reload;
                self.scheduleOverflow(late);
            }
        }

        fn scheduleOverflow(self: *Self, late: u64) void {
            const when = (@as(u64, 0x10000) - self._counter) * self.frequency();

            self._start_timestamp = self.sched.now();
            self.sched.push(.{ .TimerOverflow = id }, self.sched.now() + when - late);
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
