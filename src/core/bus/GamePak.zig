const std = @import("std");

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

pub fn init(allocator: Allocator, rom_path: []const u8, save_path: ?[]const u8) !Self {
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
        .gpio = try Gpio.init(allocator, .Rtc),
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
        // TODO: Maybe make this comptime known? Removes some if statements
        kind: Kind,

        const Kind = enum {
            Rtc,
            None,
        };

        fn step(self: *Device, value: u4) void {
            switch (self.kind) {
                .Rtc => {
                    const clock = @ptrCast(*Clock, @alignCast(@alignOf(*Clock), self.ptr.?));

                    clock.step(Clock.GpioData{ .raw = value });
                },
                .None => {},
            }
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

    fn init(allocator: Allocator, kind: Device.Kind) !*This {
        const self = try allocator.create(This);

        self.* = .{
            .data = 0b0000,
            .direction = 0b1111, // TODO: What is GPIO DIrection set to by default?
            .cnt = 0b0,

            .device = switch (kind) {
                .Rtc => blk: {
                    const clock = try allocator.create(Clock);
                    clock.init(self);

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
        log.debug("RTC: Wrote 0b{b:0>4} to {}", .{ value, reg });

        // if (reg == .Data)
        // log.err("original: 0b{b:0>4} masked: 0b{b:0>4} result: 0b{b:0>4}", .{ self.data, value & self.direction, self.data | (value & self.direction) });

        switch (reg) {
            .Data => {
                const masked_value = value & self.direction;

                self.device.step(masked_value);
                self.data = masked_value;
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
    state: State,
    cnt: Control,

    year: u8,
    month: u5,
    day: u6,
    day_of_week: u3,
    hour: u6,
    minute: u7,
    second: u7,

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

    const Writer = struct {
        buf: u8,
        i: u4,

        /// The Number of bytes written to since last reset
        count: u8,

        fn push(self: *Writer, value: u1) void {
            const idx = @intCast(u3, self.i);
            self.buf = (self.buf & ~(@as(u8, 1) << idx)) | @as(u8, value) << idx;
            self.i += 1;
        }

        fn lap(self: *Writer) void {
            self.buf = 0;
            self.i = 0;
            self.count += 1;
        }

        fn reset(self: *Writer) void {
            self.buf = 0;
            self.i = 0;
            self.count = 0;
        }

        fn isFinished(self: *const Writer) bool {
            return self.i >= 8;
        }

        fn getCount(self: *const Writer) u8 {
            return self.count;
        }

        fn getValue(self: *const Writer) u8 {
            return self.buf;
        }
    };

    const Command = struct {
        buf: u8,
        i: u4,

        fn push(self: *Command, value: u1) void {
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
            // If high Nybble does not contain 0x6, reverse the order of the nybbles.
            // For some reason RTC commands can be LSB or MSB which is funny
            return if (self.buf >> 4 & 0xF == 0x6) self.buf else (self.buf & 0xF) << 4 | (self.buf >> 4 & 0xF);
        }

        fn handleCommand(self: *const Command, rtc: *Clock) State {
            log.info("RTC: Failed to handle Command 0b{b:0>8} aka 0x{X:0>2}", .{ self.buf, self.buf });
            const command = self.getCommand();

            const is_write = command & 1 == 0;
            const rtc_register = @intCast(u3, command >> 1 & 0x7); // TODO: Make Truncate

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

    const GpioData = extern union {
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

    fn init(ptr: *This, gpio: *const Gpio) void {
        ptr.* = .{
            .cmd = .{ .buf = 0, .i = 0 },
            .writer = .{ .buf = 0, .i = 0, .count = 0 },
            .state = .Idle,
            .cnt = .{ .raw = 0 },
            .year = 0,
            .month = 0,
            .day = 0,
            .day_of_week = 0,
            .hour = 0,
            .minute = 0,
            .second = 0,
            .gpio = gpio,
        };
    }

    fn attachGpio(self: *This, gpio: *const Gpio) void {
        self.gpio = gpio;
    }

    fn step(self: *This, value: GpioData) void {
        const cache: GpioData = .{ .raw = self.gpio.data };

        switch (self.state) {
            .Idle => {
                // If SCK is high and CS rises, then prepare for Command
                // FIXME: Maybe check incoming value to see if SCK is also high?
                if (cache.sck.read()) {
                    if (!cache.cs.read() and value.cs.read()) {
                        log.err("RTC: Entering Command Mode", .{});
                        self.state = .CommandInput;
                        self.cmd.reset();
                    }
                }
            },
            .CommandInput => {
                if (!value.cs.read()) log.err("RTC: Expected CS to be set during {}, however CS was cleared", .{self.state});

                if (!cache.sck.read() and value.sck.read()) {
                    // If SCK rises, sample SIO
                    log.debug("RTC: Sampled 0b{b:0>1} from SIO", .{@boolToInt(value.sio.read())});
                    self.cmd.push(@boolToInt(value.sio.read()));

                    if (self.cmd.isFinished()) {
                        self.state = self.cmd.handleCommand(self);
                    }
                }
            },
            State{ .Write = .Control } => {
                if (!value.cs.read()) log.err("RTC: Expected CS to be set during {}, however CS was cleared", .{self.state});

                if (!cache.sck.read() and value.sck.read()) {
                    // If SCK rises, sample SIO

                    log.debug("RTC: Sampled 0b{b:0>1} from SIO", .{@boolToInt(value.sio.read())});
                    self.writer.push(@boolToInt(value.sio.read()));

                    if (self.writer.isFinished()) {
                        self.writer.lap();
                        self.cnt.raw = self.writer.getValue();

                        // FIXME: Move this to a constant or something
                        if (self.writer.getCount() == 1) {
                            self.writer.reset();
                            self.state = .Idle;
                        }
                    }
                }
            },
            else => {
                // TODO: Implement Read/Writes for Date/Time and Time and Control
                log.err("RTC: Ignored request to handle {} command", .{self.state});
                self.state = .Idle;
            },
        }
    }

    fn reset(self: *This) void {
        // mGBA and NBA only zero the control register
        // we'll do the same
        self.cnt.raw = 0;
        log.info("RTC: Reset executed (control register was zeroed)", .{});
    }

    fn irq(_: *const This) void {
        // TODO: Force GamePak IRQ
        log.err("RTC: TODO: Force GamePak IRQ", .{});
    }
};
