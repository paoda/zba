const std = @import("std");
const util = @import("../../util.zig");

const TimerControl = @import("io.zig").TimerControl;
const Scheduler = @import("../scheduler.zig").Scheduler;
const Arm7tdmi = @import("arm32").Arm7tdmi;
const Bus = @import("../Bus.zig");

const handleInterrupt = @import("../cpu_util.zig").handleInterrupt;

pub const TimerTuple = struct { Timer(0), Timer(1), Timer(2), Timer(3) };
const log = std.log.scoped(.Timer);

const getHalf = util.getHalf;
const setHalf = util.setHalf;

pub fn create(sched: *Scheduler) TimerTuple {
    return .{ Timer(0).init(sched), Timer(1).init(sched), Timer(2).init(sched), Timer(3).init(sched) };
}

pub fn read(comptime T: type, tim: *const TimerTuple, addr: u32) ?T {
    const nybble_addr = @truncate(u4, addr);

    return switch (T) {
        u32 => switch (nybble_addr) {
            0x0 => @as(T, tim.*[0].cnt.raw) << 16 | tim.*[0].timcntL(),
            0x4 => @as(T, tim.*[1].cnt.raw) << 16 | tim.*[1].timcntL(),
            0x8 => @as(T, tim.*[2].cnt.raw) << 16 | tim.*[2].timcntL(),
            0xC => @as(T, tim.*[3].cnt.raw) << 16 | tim.*[3].timcntL(),
            else => util.io.read.err(T, log, "unaligned {} read from 0x{X:0>8}", .{ T, addr }),
        },
        u16 => switch (nybble_addr) {
            0x0 => tim.*[0].timcntL(),
            0x2 => tim.*[0].cnt.raw,

            0x4 => tim.*[1].timcntL(),
            0x6 => tim.*[1].cnt.raw,

            0x8 => tim.*[2].timcntL(),
            0xA => tim.*[2].cnt.raw,

            0xC => tim.*[3].timcntL(),
            0xE => tim.*[3].cnt.raw,
            else => util.io.read.err(T, log, "unaligned {} read from 0x{X:0>8}", .{ T, addr }),
        },
        u8 => switch (nybble_addr) {
            0x0, 0x1 => @truncate(T, tim.*[0].timcntL() >> getHalf(nybble_addr)),
            0x2, 0x3 => @truncate(T, tim.*[0].cnt.raw >> getHalf(nybble_addr)),

            0x4, 0x5 => @truncate(T, tim.*[1].timcntL() >> getHalf(nybble_addr)),
            0x6, 0x7 => @truncate(T, tim.*[1].cnt.raw >> getHalf(nybble_addr)),

            0x8, 0x9 => @truncate(T, tim.*[2].timcntL() >> getHalf(nybble_addr)),
            0xA, 0xB => @truncate(T, tim.*[2].cnt.raw >> getHalf(nybble_addr)),

            0xC, 0xD => @truncate(T, tim.*[3].timcntL() >> getHalf(nybble_addr)),
            0xE, 0xF => @truncate(T, tim.*[3].cnt.raw >> getHalf(nybble_addr)),
        },
        else => @compileError("TIM: Unsupported read width"),
    };
}

pub fn write(comptime T: type, tim: *TimerTuple, addr: u32, value: T) void {
    const nybble_addr = @truncate(u4, addr);

    return switch (T) {
        u32 => switch (nybble_addr) {
            0x0 => tim.*[0].setTimcnt(value),
            0x4 => tim.*[1].setTimcnt(value),
            0x8 => tim.*[2].setTimcnt(value),
            0xC => tim.*[3].setTimcnt(value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>8}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u16 => switch (nybble_addr) {
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
        u8 => switch (nybble_addr) {
            0x0, 0x1 => tim.*[0].setTimcntL(setHalf(u16, tim.*[0]._reload, nybble_addr, value)),
            0x2, 0x3 => tim.*[0].setTimcntH(setHalf(u16, tim.*[0].cnt.raw, nybble_addr, value)),

            0x4, 0x5 => tim.*[1].setTimcntL(setHalf(u16, tim.*[1]._reload, nybble_addr, value)),
            0x6, 0x7 => tim.*[1].setTimcntH(setHalf(u16, tim.*[1].cnt.raw, nybble_addr, value)),

            0x8, 0x9 => tim.*[2].setTimcntL(setHalf(u16, tim.*[2]._reload, nybble_addr, value)),
            0xA, 0xB => tim.*[2].setTimcntH(setHalf(u16, tim.*[2].cnt.raw, nybble_addr, value)),

            0xC, 0xD => tim.*[3].setTimcntL(setHalf(u16, tim.*[3]._reload, nybble_addr, value)),
            0xE, 0xF => tim.*[3].setTimcntH(setHalf(u16, tim.*[3].cnt.raw, nybble_addr, value)),
        },
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

        pub fn reset(self: *Self) void {
            const scheduler = self.sched;

            self.* = Self.init(scheduler);
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

            if (self.cnt.enabled.read()) {
                // timer was already enabled

                // If enabled falling edge or cascade falling edge, timer is paused
                if (!new.enabled.read() or (!self.cnt.cascade.read() and new.cascade.read())) {
                    self.sched.removeScheduledEvent(.{ .TimerOverflow = id });

                    // Counter should hold the value it stopped at meaning we have to calculate it now
                    self._counter +%= @truncate(u16, (self.sched.now() - self._start_timestamp) / self.frequency());
                }

                // the timer has always been enabled, but the cascade bit which was blocking the timer has been unset
                if (new.enabled.read() and (self.cnt.cascade.read() and !new.cascade.read())) {
                    // we want to reschedule the timer event, however we won't reload the counter.
                    // the invariant here is that self._counter holds the already calculated paused value

                    self.rescheduleTimerExpire(0);
                }
            } else {
                // the timer was previously disabeld

                if (new.enabled.read()) {
                    // timer should start counting (with a reloaded counter value)
                    self._counter = self._reload;

                    // if cascade happens to be set, the timer doesn't actually do anything though
                    if (!new.cascade.read()) self.rescheduleTimerExpire(0);
                }
            }

            self.cnt.raw = halfword;
        }

        pub fn onTimerExpire(self: *Self, cpu: *Arm7tdmi, late: u64) void {
            // Fire IRQ if enabled
            const bus_ptr = @ptrCast(*Bus, @alignCast(@alignOf(Bus), cpu.bus.ptr));

            const io = &bus_ptr.io;

            if (self.cnt.irq.read()) {
                switch (id) {
                    0 => io.irq.tim0.set(),
                    1 => io.irq.tim1.set(),
                    2 => io.irq.tim2.set(),
                    3 => io.irq.tim3.set(),
                }

                handleInterrupt(cpu);
            }

            // DMA Sound Things
            if (id == 0 or id == 1) {
                bus_ptr.apu.onDmaAudioSampleRequest(cpu, id);
            }

            // Perform Cascade Behaviour
            switch (id) {
                inline 0, 1, 2 => |idx| {
                    const next = idx + 1;

                    if (bus_ptr.tim[next].cnt.cascade.read()) {
                        bus_ptr.tim[next]._counter +%= 1;
                        if (bus_ptr.tim[next]._counter == 0) bus_ptr.tim[next].onTimerExpire(cpu, late);
                    }
                },
                3 => {}, // THere is no timer for TIM3 to cascade to
            }

            // Reschedule Timer if we're not cascading
            // TIM0 cascade value is N/A
            if (id == 0 or !self.cnt.cascade.read()) {
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
