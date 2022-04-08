const std = @import("std");

const Bios = @import("bus/Bios.zig");
const Ewram = @import("bus/Ewram.zig");
const GamePak = @import("bus/GamePak.zig");
const Io = @import("bus/io.zig").Io;
const Iwram = @import("bus/Iwram.zig");
const Ppu = @import("ppu.zig").Ppu;
const Apu = @import("apu.zig").Apu;
const DmaControllers = @import("bus/dma.zig").DmaControllers;
const Timers = @import("bus/timer.zig").Timers;
const Scheduler = @import("scheduler.zig").Scheduler;

const io = @import("bus/io.zig");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Bus);

const rotr = @import("util.zig").rotr;

const Self = @This();

const panic_on_und_bus: bool = false;

pak: GamePak,
bios: Bios,
ppu: Ppu,
apu: Apu,
dma: DmaControllers,
tim: Timers,
iwram: Iwram,
ewram: Ewram,

io: Io,

pub fn init(alloc: Allocator, sched: *Scheduler, rom_path: []const u8, bios_path: ?[]const u8, save_path: ?[]const u8) !Self {
    return Self{
        .pak = try GamePak.init(alloc, rom_path, save_path),
        .bios = try Bios.init(alloc, bios_path),
        .ppu = try Ppu.init(alloc, sched),
        .apu = Apu.init(),
        .iwram = try Iwram.init(alloc),
        .ewram = try Ewram.init(alloc),
        .dma = DmaControllers.init(),
        .tim = Timers.init(sched),
        .io = Io.init(),
    };
}

pub fn deinit(self: Self) void {
    self.iwram.deinit();
    self.ewram.deinit();
    self.pak.deinit();
    self.bios.deinit();
    self.ppu.deinit();
}

pub fn read(self: *const Self, comptime T: type, address: u32) T {
    const page = @truncate(u8, address >> 24);
    const align_addr = alignAddress(T, address);

    return switch (page) {
        // General Internal Memory
        0x00 => self.bios.read(T, align_addr),
        0x02 => self.ewram.read(T, align_addr),
        0x03 => self.iwram.read(T, align_addr),
        0x04 => switch (T) {
            u32 => io.read32(self, align_addr),
            u16 => io.read16(self, align_addr),
            u8 => io.read8(self, align_addr),
            else => @compileError("I/O: Unsupported read width"),
        },

        // Internal Display Memory
        0x05 => self.ppu.palette.read(T, align_addr),
        0x06 => self.ppu.vram.read(T, align_addr),
        0x07 => self.ppu.oam.read(T, align_addr),

        // External Memory (Game Pak)
        0x08...0x0D => self.pak.read(T, align_addr),
        0x0E...0x0F => blk: {
            const value = self.pak.backup.read(address);

            const multiplier = switch (T) {
                u32 => 0x01010101,
                u16 => 0x0101,
                u8 => 1,
                else => @compileError("Backup: Unsupported read width"),
            };

            break :blk @as(T, value) * multiplier;
        },
        else => undRead("Tried to read {} from 0x{X:0>8}", .{ T, address }),
    };
}

pub fn write(self: *Self, comptime T: type, address: u32, value: T) void {
    const page = @truncate(u8, address >> 24);
    const align_addr = alignAddress(T, address);

    switch (page) {
        // General Internal Memory
        0x00 => self.bios.write(T, align_addr, value),
        0x02 => self.ewram.write(T, align_addr, value),
        0x03 => self.iwram.write(T, align_addr, value),
        0x04 => switch (T) {
            u32 => io.write32(self, align_addr, value),
            u16 => io.write16(self, align_addr, value),
            u8 => io.write8(self, align_addr, value),
            else => @compileError("I/O: Unsupported write width"),
        },

        // Internal Display Memory
        0x05 => self.ppu.palette.write(T, align_addr, value),
        0x06 => self.ppu.vram.write(T, align_addr, value),
        0x07 => self.ppu.oam.write(T, align_addr, value),

        // External Memory (Game Pak)
        0x08...0x0D => {},
        0x0E...0x0F => {
            const rotate_by = switch (T) {
                u32 => address & 3,
                u16 => address & 1,
                u8 => 0,
                else => @compileError("Backup: Unsupported write width"),
            };

            self.pak.backup.write(address, @truncate(u8, rotr(T, value, 8 * rotate_by)));
        },
        else => undWrite("Tried to write {} 0x{X:} to 0x{X:0>8}", .{ T, value, address }),
    }
}

fn alignAddress(comptime T: type, address: u32) u32 {
    return switch (T) {
        u32 => address & 0xFFFF_FFFC,
        u16 => address & 0xFFFF_FFFE,
        u8 => address,
        else => @compileError("Bus: Invalid read/write type"),
    };
}

fn undRead(comptime format: []const u8, args: anytype) u8 {
    if (panic_on_und_bus) std.debug.panic(format, args) else log.warn(format, args);
    return 0;
}

fn undWrite(comptime format: []const u8, args: anytype) void {
    if (panic_on_und_bus) std.debug.panic(format, args) else log.warn(format, args);
}
