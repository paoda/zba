const std = @import("std");
const Bit = @import("bitjuggle").Boolean;
const DateTime = @import("datetime").datetime.Datetime;

const Arm7tdmi = @import("arm32").Arm7tdmi;
const Bus = @import("../Bus.zig");
const Scheduler = @import("../scheduler.zig").Scheduler;
const Allocator = std.mem.Allocator;

const handleInterrupt = @import("../cpu_util.zig").handleInterrupt;

/// GPIO Register Implementation
pub const Gpio = struct {
    const Self = @This();
    const log = std.log.scoped(.Gpio);

    data: u4,
    direction: u4,
    cnt: u1,

    device: Device,

    const Register = enum { Data, Direction, Control };

    pub const Device = struct {
        ptr: ?*anyopaque,
        kind: Kind, // TODO: Make comptime known?

        pub const Kind = enum { Rtc, None };

        fn step(self: *Device, value: u4) u4 {
            return switch (self.kind) {
                .Rtc => blk: {
                    const clock: *Clock = @ptrCast(@alignCast(self.ptr.?));
                    break :blk clock.step(.{ .raw = value });
                },
                .None => value,
            };
        }

        fn init(kind: Kind, ptr: ?*anyopaque) Device {
            return .{ .kind = kind, .ptr = ptr };
        }
    };

    pub fn write(self: *Self, comptime reg: Register, value: if (reg == .Control) u1 else u4) void {
        switch (reg) {
            .Data => {
                const masked_value = value & self.direction;

                // The value which is actually stored in the GPIO register
                // might be modified by the device implementing the GPIO interface e.g. RTC reads
                self.data = self.device.step(masked_value);
            },
            .Direction => self.direction = value,
            .Control => self.cnt = value,
        }
    }

    pub fn read(self: *const Self, comptime reg: Register) if (reg == .Control) u1 else u4 {
        if (self.cnt == 0) return 0;

        return switch (reg) {
            .Data => self.data & ~self.direction,
            .Direction => self.direction,
            .Control => self.cnt,
        };
    }

    pub fn init(allocator: Allocator, cpu: *Arm7tdmi, kind: Device.Kind) !*Self {
        log.info("Device: {}", .{kind});

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .data = 0b0000,
            .direction = 0b1111, // TODO: What is GPIO Direction set to by default?
            .cnt = 0b0,

            .device = switch (kind) {
                .Rtc => blk: {
                    const clock = try allocator.create(Clock);
                    clock.init(cpu, self);

                    break :blk Device{ .kind = kind, .ptr = clock };
                },
                .None => Device{ .kind = kind, .ptr = null },
            },
        };

        return self;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.device.kind) {
            .Rtc => allocator.destroy(@as(*Clock, @ptrCast(@alignCast(self.device.ptr.?)))),
            .None => {},
        }

        self.* = undefined;
    }
};

/// GBA Real Time Clock
pub const Clock = struct {
    const Self = @This();
    const log = std.log.scoped(.Rtc);

    writer: Writer,
    reader: Reader,
    state: State,
    cnt: Control,

    year: u8,
    month: u5,
    day: u6,
    weekday: u3,
    hour: u6,
    minute: u7,
    second: u7,

    cpu: *Arm7tdmi,
    gpio: *const Gpio,

    const Register = enum {
        Control,
        DateTime,
        Time,
    };

    const State = union(enum) {
        Idle,
        Command,
        Write: Register,
        Read: Register,
    };

    const Reader = struct {
        i: u4,
        count: u8,

        /// Reads a bit from RTC registers. Which bit it reads is dependent on
        ///
        /// 1. The RTC State Machine, whitch tells us which register we're accessing
        /// 2. A `count`, which keeps track of which byte is currently being read
        /// 3. An index, which keeps track of which bit of the byte determined by `count` is being read
        fn read(self: *Reader, clock: *const Clock, register: Register) u1 {
            const idx: u3 = @intCast(self.i);
            defer self.i += 1;

            // FIXME: What do I do about the unused bits?
            return switch (register) {
                .Control => @truncate(switch (self.count) {
                    0 => clock.cnt.raw >> idx,
                    else => std.debug.panic("Tried to read from byte #{} of {} (hint: there's only 1 byte)", .{ self.count, register }),
                }),
                .DateTime => @truncate(switch (self.count) {
                    // Date
                    0 => clock.year >> idx,
                    1 => @as(u8, clock.month) >> idx,
                    2 => @as(u8, clock.day) >> idx,
                    3 => @as(u8, clock.weekday) >> idx,

                    // Time
                    4 => @as(u8, clock.hour) >> idx,
                    5 => @as(u8, clock.minute) >> idx,
                    6 => @as(u8, clock.second) >> idx,
                    else => std.debug.panic("Tried to read from byte #{} of {} (hint: there's only 7 bytes)", .{ self.count, register }),
                }),
                .Time => @truncate(switch (self.count) {
                    0 => @as(u8, clock.hour) >> idx,
                    1 => @as(u8, clock.minute) >> idx,
                    2 => @as(u8, clock.second) >> idx,
                    else => std.debug.panic("Tried to read from byte #{} of {} (hint: there's only 3 bytes)", .{ self.count, register }),
                }),
            };
        }

        /// Is true when a Reader has read a u8's worth of bits
        fn finished(self: *const Reader) bool {
            return self.i >= 8;
        }

        /// Resets the index used to shift bits out of RTC registers
        /// and `count`, which is used to keep track of which byte we're reading
        /// is incremeneted
        fn lap(self: *Reader) void {
            self.i = 0;
            self.count += 1;
        }

        /// Resets the state of a `Reader` in preparation for a future
        /// read command
        fn reset(self: *Reader) void {
            self.i = 0;
            self.count = 0;
        }
    };

    const Writer = struct {
        buf: u8,
        i: u4,

        /// The Number of bytes written since last reset
        count: u8,

        /// Append a bit to the internal bit buffer (aka an integer)
        fn push(self: *Writer, value: u1) void {
            const idx: u3 = @intCast(self.i);
            self.buf = (self.buf & ~(@as(u8, 1) << idx)) | @as(u8, value) << idx;
            self.i += 1;
        }

        /// Takes the contents of the internal buffer and writes it to an RTC register
        /// Where it writes to is dependent on:
        ///
        /// 1. The RTC State Machine, whitch tells us which register we're accessing
        /// 2. A `count`, which keeps track of which byte is currently being read
        fn write(self: *const Writer, clock: *Clock, register: Register) void {
            // FIXME: What do do about unused bits?
            switch (register) {
                .Control => switch (self.count) {
                    0 => clock.cnt.raw = (clock.cnt.raw & 0x80) | (self.buf & 0x7F), // Bit 7 read-only
                    else => std.debug.panic("Tried to write to byte #{} of {} (hint: there's only 1 byte)", .{ self.count, register }),
                },
                .DateTime, .Time => log.debug("Ignoring {} write", .{register}),
            }
        }

        /// Is true when 8 bits have been shifted into the internal buffer
        fn finished(self: *const Writer) bool {
            return self.i >= 8;
        }

        /// Resets the internal buffer
        /// resets the index used to shift bits into the internal buffer
        /// increments `count` (which keeps track of byte offsets) by one
        fn lap(self: *Writer) void {
            self.buf = 0;
            self.i = 0;
            self.count += 1;
        }

        /// Resets `Writer` to a clean state in preparation for a future write command
        fn reset(self: *Writer) void {
            self.buf = 0;
            self.i = 0;
            self.count = 0;
        }
    };

    const Data = extern union {
        sck: Bit(u8, 0),
        sio: Bit(u8, 1),
        cs: Bit(u8, 2),
        raw: u8,
    };

    const Control = extern union {
        /// Unknown, value should be preserved though
        unk: Bit(u8, 1),
        /// Per-minute IRQ
        /// If set, fire a Gamepak IRQ every 30s,
        irq: Bit(u8, 3),
        /// 12/24 Hour Bit
        /// If set, 12h mode
        /// If cleared, 24h mode
        mode: Bit(u8, 6),
        /// Read-Only, bit cleared on read
        /// If is set, means that there has been a failure / time has been lost
        off: Bit(u8, 7),
        raw: u8,
    };

    fn init(ptr: *Self, cpu: *Arm7tdmi, gpio: *const Gpio) void {
        ptr.* = .{
            .writer = .{ .buf = 0, .i = 0, .count = 0 },
            .reader = .{ .i = 0, .count = 0 },
            .state = .Idle,
            .cnt = .{ .raw = 0 },
            .year = 0x01,
            .month = 0x6,
            .day = 0x13,
            .weekday = 0x3,
            .hour = 0x23,
            .minute = 0x59,
            .second = 0x59,
            .cpu = cpu,
            .gpio = gpio, // Can't use Arm7tdmi ptr b/c not initialized yet
        };

        const sched_ptr: *Scheduler = @ptrCast(@alignCast(cpu.sched.ptr));
        sched_ptr.push(.RealTimeClock, 1 << 24); // Every Second
    }

    pub fn onClockUpdate(self: *Self, late: u64) void {
        const sched_ptr: *Scheduler = @ptrCast(@alignCast(self.cpu.sched.ptr));
        sched_ptr.push(.RealTimeClock, (1 << 24) -| late); // Reschedule

        const now = DateTime.now();
        self.year = bcd(@intCast(now.date.year - 2000));
        self.month = @truncate(bcd(now.date.month));
        self.day = @truncate(bcd(now.date.day));
        self.weekday = @truncate(bcd((now.date.weekday() + 1) % 7)); // API is Monday = 0, Sunday = 6. We want Sunday = 0, Saturday = 6
        self.hour = @truncate(bcd(now.time.hour));
        self.minute = @truncate(bcd(now.time.minute));
        self.second = @truncate(bcd(now.time.second));
    }

    fn step(self: *Self, value: Data) u4 {
        const cache: Data = .{ .raw = self.gpio.data };

        return switch (self.state) {
            .Idle => blk: {
                // FIXME: Maybe check incoming value to see if SCK is also high?
                if (cache.sck.read()) {
                    if (!cache.cs.read() and value.cs.read()) {
                        log.debug("Entering Command Mode", .{});
                        self.state = .Command;
                    }
                }

                break :blk @truncate(value.raw);
            },
            .Command => blk: {
                if (!value.cs.read()) log.err("Expected CS to be set during {}, however CS was cleared", .{self.state});

                // If SCK rises, sample SIO
                if (!cache.sck.read() and value.sck.read()) {
                    self.writer.push(@intFromBool(value.sio.read()));

                    if (self.writer.finished()) {
                        self.state = self.processCommand(self.writer.buf);
                        self.writer.reset();

                        log.debug("Switching to {}", .{self.state});
                    }
                }

                break :blk @truncate(value.raw);
            },
            .Write => |register| blk: {
                if (!value.cs.read()) log.err("Expected CS to be set during {}, however CS was cleared", .{self.state});

                // If SCK rises, sample SIO
                if (!cache.sck.read() and value.sck.read()) {
                    self.writer.push(@intFromBool(value.sio.read()));

                    const register_width: u32 = switch (register) {
                        .Control => 1,
                        .DateTime => 7,
                        .Time => 3,
                    };

                    if (self.writer.finished()) {
                        self.writer.write(self, register); // write inner buffer to RTC register
                        self.writer.lap();

                        if (self.writer.count == register_width) {
                            self.writer.reset();
                            self.state = .Idle;
                        }
                    }
                }

                break :blk @truncate(value.raw);
            },
            .Read => |register| blk: {
                if (!value.cs.read()) log.err("Expected CS to be set during {}, however CS was cleared", .{self.state});
                var ret = value;

                // if SCK rises, sample SIO
                if (!cache.sck.read() and value.sck.read()) {
                    ret.sio.write(self.reader.read(self, register) == 0b1);

                    const register_width: u32 = switch (register) {
                        .Control => 1,
                        .DateTime => 7,
                        .Time => 3,
                    };

                    if (self.reader.finished()) {
                        self.reader.lap();

                        if (self.reader.count == register_width) {
                            self.reader.reset();
                            self.state = .Idle;
                        }
                    }
                }

                break :blk @truncate(ret.raw);
            },
        };
    }

    fn reset(self: *Self) void {
        // mGBA and NBA only zero the control register. We will do the same
        log.debug("Reset (control register was zeroed)", .{});

        self.cnt.raw = 0;
    }

    fn irq(self: *Self) void {
        const bus_ptr: *Bus = @ptrCast(@alignCast(self.cpu.bus.ptr));

        // TODO: Confirm that this is the right behaviour
        log.debug("Force GamePak IRQ", .{});

        bus_ptr.io.irq.game_pak.write(true);
        handleInterrupt(self.cpu);
    }

    fn processCommand(self: *Self, raw_command: u8) State {
        const command = blk: {
            // If High Nybble is 0x6, no need to switch the endianness
            if (raw_command >> 4 & 0xF == 0x6) break :blk raw_command;

            // Turns out reversing the order of bits isn't trivial at all
            // https://stackoverflow.com/questions/2602823/in-c-c-whats-the-simplest-way-to-reverse-the-order-of-bits-in-a-byte
            var ret = raw_command;
            ret = (ret & 0xF0) >> 4 | (ret & 0x0F) << 4;
            ret = (ret & 0xCC) >> 2 | (ret & 0x33) << 2;
            ret = (ret & 0xAA) >> 1 | (ret & 0x55) << 1;

            break :blk ret;
        };
        log.debug("Handling Command 0x{X:0>2} [0b{b:0>8}]", .{ command, command });

        const is_write = command & 1 == 0;
        const rtc_register: u3 = @truncate(command >> 1 & 0x7);

        if (is_write) {
            return switch (rtc_register) {
                0 => blk: {
                    self.reset();
                    break :blk .Idle;
                },
                1 => .{ .Write = .Control },
                2 => .{ .Write = .DateTime },
                3 => .{ .Write = .Time },
                6 => blk: {
                    self.irq();
                    break :blk .Idle;
                },
                4, 5, 7 => .Idle,
            };
        } else {
            return switch (rtc_register) {
                1 => .{ .Read = .Control },
                2 => .{ .Read = .DateTime },
                3 => .{ .Read = .Time },
                0, 4, 5, 6, 7 => .Idle, // Do Nothing
            };
        }
    }
};

/// Converts an 8-bit unsigned integer to its BCD representation.
/// Note: Algorithm only works for values between 0 and 99 inclusive.
fn bcd(value: u8) u8 {
    return ((value / 10) << 4) + (value % 10);
}
