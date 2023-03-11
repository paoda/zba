const std = @import("std");
const config = @import("../../config.zig");

const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const Backup = @import("backup.zig").Backup;
const Gpio = @import("gpio.zig").Gpio;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.GamePak);

const Self = @This();

title: [12]u8,
buf: []u8,
allocator: Allocator,
backup: Backup,
gpio: *Gpio,

pub fn read(self: *Self, comptime T: type, address: u32) T {
    const addr = address & 0x1FF_FFFF;

    if (self.backup.kind == .Eeprom) {
        if (self.buf.len > 0x100_0000) { // Large
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

inline fn get(self: *const Self, i: u32) u8 {
    @setRuntimeSafety(false);
    if (i < self.buf.len) return self.buf[i];

    const lhs = i >> 1 & 0xFFFF;
    return @truncate(u8, lhs >> 8 * @truncate(u5, i & 1));
}

pub fn dbgRead(self: *const Self, comptime T: type, address: u32) T {
    const addr = address & 0x1FF_FFFF;

    if (self.backup.kind == .Eeprom) {
        if (self.buf.len > 0x100_0000) { // Large
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

    if (self.gpio.cnt == 1) {
        // GPIO Can be read from
        // We assume that this will only be true when a ROM actually does want something from GPIO

        switch (T) {
            u32 => switch (address) {
                // FIXME: Do I even need to implement these?
                0x0800_00C4 => std.debug.panic("Handle 32-bit GPIO Data/Direction Reads", .{}),
                0x0800_00C6 => std.debug.panic("Handle 32-bit GPIO Direction/Control Reads", .{}),
                0x0800_00C8 => std.debug.panic("Handle 32-bit GPIO Control Reads", .{}),
                else => {},
            },
            u16 => switch (address) {
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

pub fn write(self: *Self, comptime T: type, word_count: u16, address: u32, value: T) void {
    const addr = address & 0x1FF_FFFF;

    if (self.backup.kind == .Eeprom) {
        const bit = @truncate(u1, value);

        if (self.buf.len > 0x100_0000) { // Large
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

pub fn init(allocator: Allocator, cpu: *Arm7tdmi, maybe_rom: ?[]const u8, maybe_save: ?[]const u8) !Self {
    const Device = Gpio.Device;

    const items: struct { []u8, [12]u8, Backup.Kind, Device.Kind } = if (maybe_rom) |file_path| blk: {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const buffer = try file.readToEndAlloc(allocator, try file.getEndPos());
        const title = buffer[0xA0..0xAC];
        logHeader(buffer, title);

        const device_kind = if (config.config().guest.force_rtc) .Rtc else guessDevice(buffer);

        break :blk .{ buffer, title.*, Backup.guess(buffer), device_kind };
    } else .{ try allocator.alloc(u8, 0), [_]u8{0} ** 12, .None, .None };

    const title = items[1];

    return .{
        .buf = items[0],
        .allocator = allocator,
        .title = title,
        .backup = try Backup.init(allocator, items[2], title, maybe_save),
        .gpio = try Gpio.init(allocator, cpu, items[3]),
    };
}

pub fn deinit(self: *Self) void {
    self.backup.deinit();
    self.gpio.deinit(self.allocator);
    self.allocator.destroy(self.gpio);
    self.allocator.free(self.buf);
    self.* = undefined;
}

/// Searches the ROM to see if it can determine whether the ROM it's searching uses
/// any GPIO device, like a RTC for example.
fn guessDevice(buf: []const u8) Gpio.Device.Kind {
    // Try to Guess if ROM uses RTC
    const needle = "RTC_V"; // I was told SIIRTC_V, though Pokemen Firered (USA) is a false negative

    // TODO: Use new for loop syntax?
    var i: usize = 0;
    while ((i + needle.len) < buf.len) : (i += 1) {
        if (std.mem.eql(u8, needle, buf[i..(i + needle.len)])) return .Rtc;
    }

    // TODO: Detect other GPIO devices
    return .None;
}

fn logHeader(buf: []const u8, title: *const [12]u8) void {
    const version = buf[0xBC];

    log.info("Title: {s}", .{title});
    if (version != 0) log.info("Version: {}", .{version});

    log.info("Game Code: {s}", .{buf[0xAC..0xB0]});
    log.info("Maker Code: {s}", .{buf[0xB0..0xB2]});
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
