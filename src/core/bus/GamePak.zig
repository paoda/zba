const std = @import("std");

const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Backup = @import("backup.zig").Backup;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.GamePak);

const Self = @This();

title: [12]u8,
buf: []u8,
allocator: Allocator,
backup: Backup,
gpio: *Gpio,

pub fn init(allocator: Allocator, cpu: *Arm7tdmi, rom_path: []const u8, save_path: ?[]const u8) !Self {
    const file = try std.fs.cwd().openFile(rom_path, .{});
    defer file.close();

    const file_buf = try file.readToEndAlloc(allocator, try file.getEndPos());
    const title = file_buf[0xA0..0xAC].*;
    const kind = Backup.guessKind(file_buf) orelse .None;
    logHeader(file_buf, &title);

    return .{
        .buf = file_buf,
        .allocator = allocator,
        .title = title,
        .backup = try Backup.init(allocator, kind, title, save_path),
        .gpio = try Gpio.init(allocator, cpu, .Rtc),
    };
}

fn logHeader(buf: []const u8, title: *const [12]u8) void {
    const code = buf[0xAC..0xB0];
    const maker = buf[0xB0..0xB2];
    const version = buf[0xBC];

    log.info("Title: {s}", .{title});
    if (version != 0) log.info("Version: {}", .{version});
    log.info("Game Code: {s}", .{code});
    if (lookupMaker(maker)) |c| log.info("Maker: {s}", .{c}) else log.info("Maker Code: {s}", .{maker});
}

fn lookupMaker(slice: *const [2]u8) ?[]const u8 {
    const id = @as(u16, slice[1]) << 8 | @as(u16, slice[0]);
    return switch (id) {
        0x3130 => "Nintendo",
        else => null,
    };
}

inline fn isLarge(self: *const Self) bool {
    return self.buf.len > 0x100_0000;
}

pub fn deinit(self: *Self) void {
    self.backup.deinit();
    self.gpio.deinit(self.allocator);
    self.allocator.destroy(self.gpio);
    self.allocator.free(self.buf);
    self.* = undefined;
}

pub fn read(self: *Self, comptime T: type, address: u32) T {
    const addr = address & 0x1FF_FFFF;

    if (self.backup.kind == .Eeprom) {
        if (self.isLarge()) {
            // Addresses 0x1FF_FF00 to 0x1FF_FFFF are reserved from EEPROM accesses if
            // * Backup type is EEPROM
            // * Large ROM (Size is greater than 16MB)
            if (addr > 0x1FF_FEFF)
                return self.backup.eeprom.read();
        } else {
            // Addresses 0x0D00_0000 to 0x0DFF_FFFF are reserved for EEPROM accesses if
            // * Backup type is EEPROM
            // * Small ROM (less than 16MB)
            if (@truncate(u8, address >> 24) == 0x0D)
                return self.backup.eeprom.read();
        }
    }

    if (self.gpio.cnt == 1) {
        // GPIO Can be read from
        // We assume that this will only be true when a ROM actually does want something from GPIO

        switch (T) {
            u32 => switch (address) {
                // TODO: Do I even need to implement these?
                0x0800_00C4 => std.debug.panic("Handle 32-bit GPIO Data/Direction Reads", .{}),
                0x0800_00C6 => std.debug.panic("Handle 32-bit GPIO Direction/Control Reads", .{}),
                0x0800_00C8 => std.debug.panic("Handle 32-bit GPIO Control Reads", .{}),
                else => {},
            },
            u16 => switch (address) {
                // FIXME: What do 16-bit GPIO Reads look like?
                0x0800_00C4 => return self.gpio.read(.Data),
                0x0800_00C6 => return self.gpio.read(.Direction),
                0x0800_00C8 => return self.gpio.read(.Control),
                else => {},
            },
            u8 => switch (address) {
                0x0800_00C4 => return self.gpio.read(.Data),
                0x0800_00C6 => return self.gpio.read(.Direction),
                0x0800_00C8 => return self.gpio.read(.Control),
                else => {},
            },
            else => @compileError("GamePak[GPIO]: Unsupported read width"),
        }
    }

    return switch (T) {
        u32 => (@as(T, self.get(addr + 3)) << 24) | (@as(T, self.get(addr + 2)) << 16) | (@as(T, self.get(addr + 1)) << 8) | (@as(T, self.get(addr))),
        u16 => (@as(T, self.get(addr + 1)) << 8) | @as(T, self.get(addr)),
        u8 => self.get(addr),
        else => @compileError("GamePak: Unsupported read width"),
    };
}

pub fn dbgRead(self: *const Self, comptime T: type, address: u32) T {
    const addr = address & 0x1FF_FFFF;

    if (self.backup.kind == .Eeprom) {
        if (self.isLarge()) {
            // Addresses 0x1FF_FF00 to 0x1FF_FFFF are reserved from EEPROM accesses if
            // * Backup type is EEPROM
            // * Large ROM (Size is greater than 16MB)
            if (addr > 0x1FF_FEFF)
                return self.backup.eeprom.dbgRead();
        } else {
            // Addresses 0x0D00_0000 to 0x0DFF_FFFF are reserved for EEPROM accesses if
            // * Backup type is EEPROM
            // * Small ROM (less than 16MB)
            if (@truncate(u8, address >> 24) == 0x0D)
                return self.backup.eeprom.dbgRead();
        }
    }

    return switch (T) {
        u32 => (@as(T, self.get(addr + 3)) << 24) | (@as(T, self.get(addr + 2)) << 16) | (@as(T, self.get(addr + 1)) << 8) | (@as(T, self.get(addr))),
        u16 => (@as(T, self.get(addr + 1)) << 8) | @as(T, self.get(addr)),
        u8 => self.get(addr),
        else => @compileError("GamePak: Unsupported read width"),
    };
}

pub fn write(self: *Self, comptime T: type, word_count: u16, address: u32, value: T) void {
    const addr = address & 0x1FF_FFFF;

    if (self.backup.kind == .Eeprom) {
        const bit = @truncate(u1, value);

        if (self.isLarge()) {
            // Addresses 0x1FF_FF00 to 0x1FF_FFFF are reserved from EEPROM accesses if
            // * Backup type is EEPROM
            // * Large ROM (Size is greater than 16MB)
            if (addr > 0x1FF_FEFF)
                return self.backup.eeprom.write(word_count, &self.backup.buf, bit);
        } else {
            // Addresses 0x0D00_0000 to 0x0DFF_FFFF are reserved for EEPROM accesses if
            // * Backup type is EEPROM
            // * Small ROM (less than 16MB)
            if (@truncate(u8, address >> 24) == 0x0D)
                return self.backup.eeprom.write(word_count, &self.backup.buf, bit);
        }
    }

    switch (T) {
        u32 => switch (address) {
            0x0800_00C4 => {
                self.gpio.write(.Data, @truncate(u4, value));
                self.gpio.write(.Direction, @truncate(u4, value >> 16));
            },
            0x0800_00C6 => {
                self.gpio.write(.Direction, @truncate(u4, value));
                self.gpio.write(.Control, @truncate(u1, value >> 16));
            },
            else => log.err("Wrote {} 0x{X:0>8} to 0x{X:0>8}, Unhandled", .{ T, value, address }),
        },
        u16 => switch (address) {
            0x0800_00C4 => self.gpio.write(.Data, @truncate(u4, value)),
            0x0800_00C6 => self.gpio.write(.Direction, @truncate(u4, value)),
            0x0800_00C8 => self.gpio.write(.Control, @truncate(u1, value)),
            else => log.err("Wrote {} 0x{X:0>4} to 0x{X:0>8}, Unhandled", .{ T, value, address }),
        },
        u8 => log.debug("Wrote {} 0x{X:0>2} to 0x{X:0>8}, Ignored.", .{ T, value, address }),
        else => @compileError("GamePak: Unsupported write width"),
    }
}

fn get(self: *const Self, i: u32) u8 {
    @setRuntimeSafety(false);
    if (i < self.buf.len) return self.buf[i];

    const lhs = i >> 1 & 0xFFFF;
    return @truncate(u8, lhs >> 8 * @truncate(u5, i & 1));
}

test "OOB Access" {
    const title = .{ 'H', 'E', 'L', 'L', 'O', ' ', 'W', 'O', 'R', 'L', 'D', '!' };
    const alloc = std.testing.allocator;
    const pak = Self{
        .buf = &.{},
        .alloc = alloc,
        .title = title,
        .backup = try Backup.init(alloc, .None, title, null),
    };

    std.debug.assert(pak.get(0) == 0x00); // 0x0000
    std.debug.assert(pak.get(1) == 0x00);

    std.debug.assert(pak.get(2) == 0x01); // 0x0001
    std.debug.assert(pak.get(3) == 0x00);

    std.debug.assert(pak.get(4) == 0x02); // 0x0002
    std.debug.assert(pak.get(5) == 0x00);
}

/// GPIO Register Implementation
const Gpio = struct {
    const This = @This();

    data: u4,
    direction: u4,
    cnt: u1,

    device: Device,

    const Device = struct {
        ptr: ?*anyopaque,
        kind: Kind, // TODO: Make comptime known?

        const Kind = enum { Rtc, None };

        fn step(self: *Device, value: u4) u4 {
            return switch (self.kind) {
                .Rtc => blk: {
                    const clock = @ptrCast(*Clock, @alignCast(@alignOf(*Clock), self.ptr.?));
                    break :blk clock.step(Clock.Data{ .raw = value });
                },
                .None => value,
            };
        }

        fn init(kind: Kind, ptr: ?*anyopaque) Device {
            return .{ .kind = kind, .ptr = ptr };
        }
    };

    const Register = enum {
        Data,
        Direction,
        Control,
    };

    fn init(allocator: Allocator, cpu: *Arm7tdmi, kind: Device.Kind) !*This {
        const self = try allocator.create(This);

        self.* = .{
            .data = 0b0000,
            .direction = 0b1111, // TODO: What is GPIO DIrection set to by default?
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

    fn deinit(self: *This, allocator: Allocator) void {
        switch (self.device.kind) {
            .Rtc => {
                allocator.destroy(@ptrCast(*Clock, @alignCast(@alignOf(*Clock), self.device.ptr.?)));
            },
            .None => {},
        }

        self.* = undefined;
    }

    fn write(self: *This, comptime reg: Register, value: if (reg == .Control) u1 else u4) void {
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

    fn read(self: *const This, comptime reg: Register) if (reg == .Control) u1 else u4 {
        if (self.cnt == 0) return 0;

        return switch (reg) {
            .Data => self.data & ~self.direction,
            .Direction => self.direction,
            .Control => self.cnt,
        };
    }
};

/// GBA Real Time Clock
const Clock = struct {
    const This = @This();

    cmd: Command,
    writer: Writer,
    reader: Reader,
    state: State,
    cnt: Control,

    year: u8,
    month: u5,
    day: u6,
    day_of_week: u3,
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
        CommandInput,
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
            const idx = @intCast(u3, self.i);
            defer self.i += 1;

            // FIXME: What do I do about the unused bits?
            return switch (register) {
                .Control => @truncate(u1, switch (self.count) {
                    0 => clock.cnt.raw >> idx,
                    else => {
                        log.err("RTC: {} is only 1 byte wide", .{register});
                        @panic("Out-of-bounds RTC read");
                    },
                }),
                .DateTime => @truncate(u1, switch (self.count) {
                    // Date
                    0 => clock.year >> idx,
                    1 => @as(u8, clock.month) >> idx,
                    2 => @as(u8, clock.day) >> idx,
                    3 => @as(u8, clock.day_of_week) >> idx,

                    // Time
                    4 => @as(u8, clock.hour) >> idx,
                    5 => @as(u8, clock.minute) >> idx,
                    6 => @as(u8, clock.second) >> idx,
                    else => {
                        log.err("RTC: {} is only 7 bytes wide", .{register});
                        @panic("Out-of-bounds RTC read");
                    },
                }),
                .Time => @truncate(u1, switch (self.count) {
                    0 => @as(u8, clock.hour) >> idx,
                    1 => @as(u8, clock.minute) >> idx,
                    2 => @as(u8, clock.second) >> idx,
                    else => {
                        log.err("RTC: {} is only 3 bytes wide", .{register});
                        @panic("Out-of-bounds RTC read");
                    },
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
            const idx = @intCast(u3, self.i);
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
                    0 => clock.cnt.raw = self.buf,
                    else => {
                        log.err("RTC :{} is only 1 byte wide", .{register});
                        @panic("Out-of-bounds RTC write");
                    },
                },
                .DateTime => switch (self.count) {
                    // Date
                    0 => clock.year = @truncate(@TypeOf(clock.year), self.buf),
                    1 => clock.month = @truncate(@TypeOf(clock.month), self.buf),
                    2 => clock.day = @truncate(@TypeOf(clock.day), self.buf),
                    3 => clock.day_of_week = @truncate(@TypeOf(clock.day_of_week), self.buf),

                    // Time
                    4 => clock.hour = @truncate(@TypeOf(clock.hour), self.buf),
                    5 => clock.minute = @truncate(@TypeOf(clock.minute), self.buf),
                    6 => clock.second = @truncate(@TypeOf(clock.second), self.buf),
                    else => {
                        log.err("RTC :{} is only 1 byte wide", .{register});
                        @panic("Out-of-bounds RTC write");
                    },
                },
                .Time => switch (self.count) {
                    // Time
                    0 => clock.hour = @truncate(@TypeOf(clock.hour), self.buf),
                    1 => clock.minute = @truncate(@TypeOf(clock.minute), self.buf),
                    2 => clock.second = @truncate(@TypeOf(clock.second), self.buf),
                    else => {
                        log.err("RTC :{} is only 1 byte wide", .{register});
                        @panic("Out-of-bounds RTC write");
                    },
                },
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

    const Command = struct {
        buf: u8,
        i: u4,

        fn write(self: *Command, value: u1) void {
            const idx = @intCast(u3, self.i);
            self.buf = (self.buf & ~(@as(u8, 1) << idx)) | @as(u8, value) << idx;
            self.i += 1;
        }

        fn reset(self: *Command) void {
            self.buf = 0;
            self.i = 0;
        }

        fn isFinished(self: *const Command) bool {
            return self.i >= 8;
        }

        fn getCommand(self: *const Command) u8 {
            // If High Nybble is 0x6, no need to switch the endianness
            if (self.buf >> 4 & 0xF == 0x6) return self.buf;

            // Turns out reversing the order of bits isn't trivial at all
            // https://stackoverflow.com/questions/2602823/in-c-c-whats-the-simplest-way-to-reverse-the-order-of-bits-in-a-byte
            var ret = self.buf;
            ret = (ret & 0xF0) >> 4 | (ret & 0x0F) << 4;
            ret = (ret & 0xCC) >> 2 | (ret & 0x33) << 2;
            ret = (ret & 0xAA) >> 1 | (ret & 0x55) << 1;

            return ret;
        }

        fn handleCommand(self: *const Command, rtc: *Clock) State {
            const command = self.getCommand();
            log.debug("RTC: Handling Command 0x{X:0>2} [0b{b:0>8}]", .{ command, command });

            const is_write = command & 1 == 0;
            const rtc_register = @truncate(u3, command >> 1 & 0x7);

            if (is_write) {
                return switch (rtc_register) {
                    0 => blk: {
                        rtc.reset();
                        break :blk .Idle;
                    },
                    1 => .{ .Write = .Control },
                    2 => .{ .Write = .DateTime },
                    3 => .{ .Write = .Time },
                    6 => blk: {
                        rtc.irq();
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

    fn init(ptr: *This, cpu: *Arm7tdmi, gpio: *const Gpio) void {
        ptr.* = .{
            .cmd = .{ .buf = 0, .i = 0 },
            .writer = .{ .buf = 0, .i = 0, .count = 0 },
            .reader = .{ .i = 0, .count = 0 },
            .state = .Idle,
            .cnt = .{ .raw = 0 },
            .year = 0,
            .month = 0,
            .day = 0,
            .day_of_week = 0,
            .hour = 0,
            .minute = 0,
            .second = 0,
            .cpu = cpu,
            .gpio = gpio, // Can't use Arm7tdmi ptr b/c not initialized yet
        };
    }

    fn step(self: *This, value: Data) u4 {
        const cache: Data = .{ .raw = self.gpio.data };

        return switch (self.state) {
            .Idle => blk: {
                // FIXME: Maybe check incoming value to see if SCK is also high?
                if (cache.sck.read()) {
                    if (!cache.cs.read() and value.cs.read()) {
                        log.debug("RTC: Entering Command Mode", .{});
                        self.state = .CommandInput;
                        self.cmd.reset();
                    }
                }

                break :blk @truncate(u4, value.raw);
            },
            .CommandInput => blk: {
                if (!value.cs.read()) log.err("RTC: Expected CS to be set during {}, however CS was cleared", .{self.state});

                // If SCK rises, sample SIO
                if (!cache.sck.read() and value.sck.read()) {
                    self.cmd.write(@boolToInt(value.sio.read()));

                    if (self.cmd.isFinished()) {
                        self.state = self.cmd.handleCommand(self);
                        log.debug("RTC: Switching to {}", .{self.state});
                    }
                }

                break :blk @truncate(u4, value.raw);
            },
            .Write => |register| blk: {
                if (!value.cs.read()) log.err("RTC: Expected CS to be set during {}, however CS was cleared", .{self.state});

                // If SCK rises, sample SIO
                if (!cache.sck.read() and value.sck.read()) {
                    self.writer.push(@boolToInt(value.sio.read()));

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

                break :blk @truncate(u4, value.raw);
            },
            .Read => |register| blk: {
                if (!value.cs.read()) log.err("RTC: Expected CS to be set during {}, however CS was cleared", .{self.state});
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

                break :blk @truncate(u4, ret.raw);
            },
        };
    }

    fn reset(self: *This) void {
        // mGBA and NBA only zero the control register. We will do the same
        log.debug("RTC: Reset  (control register was zeroed)", .{});

        self.cnt.raw = 0;
    }

    fn irq(self: *This) void {
        // TODO: Confirm that this is the right behaviour
        log.debug("RTC: Force GamePak IRQ", .{});

        self.cpu.bus.io.irq.game_pak.set();
        self.cpu.handleInterrupt();
    }
};
