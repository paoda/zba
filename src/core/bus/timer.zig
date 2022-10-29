const std = @import("std");
const util = @import("../../util.zig");

const TimerControl = @import("io.zig").TimerControl;
const Scheduler = @import("../scheduler.zig").Scheduler;
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;

pub const TimerTuple = std.meta.Tuple(&[_]type{ Timer(0), Timer(1), Timer(2), Timer(3) });
const log = std.log.scoped(.Timer);

pub fn create(sched: *Scheduler) TimerTuple {
    return .{ Timer(0).init(sched), Timer(1).init(sched), Timer(2).init(sched), Timer(3).init(sched) };
}

pub fn read(comptime T: type, tim: *const TimerTuple, addr: u32) ?T {
    const nybble = @truncate(u4, addr);

    return switch (T) {
        u32 => switch (nybble) {
            0x0 => @as(T, tim.*[0].cnt.raw) << 16 | tim.*[0].timcntL(),
            0x4 => @as(T, tim.*[1].cnt.raw) << 16 | tim.*[1].timcntL(),
            0x8 => @as(T, tim.*[2].cnt.raw) << 16 | tim.*[2].timcntL(),
            0xC => @as(T, tim.*[3].cnt.raw) << 16 | tim.*[3].timcntL(),
            else => util.io.read.undef(T, log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        },
        u16 => switch (nybble) {
            0x0 => tim.*[0].timcntL(),
            0x2 => tim.*[0].cnt.raw,
            0x4 => tim.*[1].timcntL(),
            0x6 => tim.*[1].cnt.raw,
            0x8 => tim.*[2].timcntL(),
            0xA => tim.*[2].cnt.raw,
            0xC => tim.*[3].timcntL(),
            0xE => tim.*[3].cnt.raw,
            else => util.io.read.undef(T, log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        },
        u8 => util.io.read.undef(T, log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        else => @compileError("TIM: Unsupported read width"),
    };
}

pub fn write(comptime T: type, tim: *TimerTuple, addr: u32, value: T) void {
    const nybble = @truncate(u4, addr);

    return switch (T) {
        u32 => switch (nybble) {
            0x0 => tim.*[0].setTimcnt(value),
            0x4 => tim.*[1].setTimcnt(value),
            0x8 => tim.*[2].setTimcnt(value),
            0xC => tim.*[3].setTimcnt(value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>8}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u16 => switch (nybble) {
            0x0 => tim.*[0].setTimcntL(value),
            0x2 => tim.*[0].setTimcntH(value),
            0x4 => tim.*[1].setTimcntL(value),
            0x6 => tim.*[1].setTimcntH(value),
            0x8 => tim.*[2].setTimcntL(value),
            0xA => tim.*[2].setTimcntH(value),
            0xC => tim.*[3].setTimcntL(value),
            0xE => tim.*[3].setTimcntH(value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>4}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u8 => util.io.write.undef(log, "Tried to write 0x{X:0>2}{} to 0x{X:0>8}", .{ value, T, addr }),
        else => @compileError("TIM: Unsupported write width"),
    };
}

fn Timer(comptime id: u2) type {
    return struct {
        const Self = @This();

        /// Read Only, Internal. Please use self.timcntL()
        _counter: u16,

        /// Write Only, Internal. Please use self.setTimcntL()
        _reload: u16,

        /// Write Only, Internal. Please use self.setTimcntH()
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

        /// TIMCNT_L Getter
        pub fn timcntL(self: *const Self) u16 {
            if (self.cnt.cascade.read() or !self.cnt.enabled.read()) return self._counter;

            return self._counter +% @truncate(u16, (self.sched.now() - self._start_timestamp) / self.frequency());
        }

        /// TIMCNT_L Setter
        pub fn setTimcntL(self: *Self, halfword: u16) void {
            self._reload = halfword;
        }

        /// TIMCNT_L & TIMCNT_H
        pub fn setTimcnt(self: *Self, word: u32) void {
            self.setTimcntL(@truncate(u16, word));
            self.setTimcntH(@truncate(u16, word >> 16));
        }

        /// TIMCNT_H
        pub fn setTimcntH(self: *Self, halfword: u16) void {
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
            if (new.enabled.read() and !new.cascade.read()) self.rescheduleTimerExpire(0);

            self.cnt.raw = halfword;
        }

        pub fn onTimerExpire(self: *Self, cpu: *Arm7tdmi, late: u64) void {
            // Fire IRQ if enabled
            const io = &cpu.bus.io;

            if (self.cnt.irq.read()) {
                switch (id) {
                    0 => io.irq.tim0.set(),
                    1 => io.irq.tim1.set(),
                    2 => io.irq.tim2.set(),
                    3 => io.irq.tim3.set(),
                }

                cpu.handleInterrupt();
            }

            // DMA Sound Things
            if (id == 0 or id == 1) {
                cpu.bus.apu.onDmaAudioSampleRequest(cpu, id);
            }

            // Perform Cascade Behaviour
            switch (id) {
                0 => if (cpu.bus.tim[1].cnt.cascade.read()) {
                    cpu.bus.tim[1]._counter +%= 1;
                    if (cpu.bus.tim[1]._counter == 0) cpu.bus.tim[1].onTimerExpire(cpu, late);
                },
                1 => if (cpu.bus.tim[2].cnt.cascade.read()) {
                    cpu.bus.tim[2]._counter +%= 1;
                    if (cpu.bus.tim[2]._counter == 0) cpu.bus.tim[2].onTimerExpire(cpu, late);
                },
                2 => if (cpu.bus.tim[3].cnt.cascade.read()) {
                    cpu.bus.tim[3]._counter +%= 1;
                    if (cpu.bus.tim[3]._counter == 0) cpu.bus.tim[3].onTimerExpire(cpu, late);
                },
                3 => {}, // There is no Timer for TIM3 to "cascade" to,
            }

            // Reschedule Timer if we're not cascading
            if (!self.cnt.cascade.read()) {
                self._counter = self._reload;
                self.rescheduleTimerExpire(late);
            }
        }

        fn rescheduleTimerExpire(self: *Self, late: u64) void {
            const when = (@as(u64, 0x10000) - self._counter) * self.frequency();

            self._start_timestamp = self.sched.now();
            self.sched.push(.{ .TimerOverflow = id }, when -| late);
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
