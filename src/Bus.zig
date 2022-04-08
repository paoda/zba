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

pub fn read32(self: *const Self, address: u32) u32 {
    const align_addr = address & 0xFFFF_FFFC; // Force Aligned

    return switch (address) {
        // General Internal Memory
        0x0000_0000...0x0000_3FFF => self.bios.read(u32, align_addr),
        0x0200_0000...0x02FF_FFFF => self.ewram.read(u32, align_addr),
        0x0300_0000...0x03FF_FFFF => self.iwram.read(u32, align_addr),
        0x0400_0000...0x0400_03FE => io.read32(self, align_addr),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.read(u32, align_addr),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.read(u32, align_addr),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.read(u32, align_addr),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.read(u32, align_addr),
        0x0A00_0000...0x0BFF_FFFF => self.pak.read(u32, align_addr),
        0x0C00_0000...0x0DFF_FFFF => self.pak.read(u32, align_addr),
        0x0E00_0000...0x0FFF_FFFF => @as(u32, self.pak.backup.read(address)) * 0x01010101,

        else => undRead("Tried to read from 0x{X:0>8}", .{address}),
    };
}

pub fn write32(self: *Self, address: u32, word: u32) void {
    const align_addr = address & 0xFFFF_FFFC; // Force Aligned

    switch (address) {
        // General Internal Memory
        0x0200_0000...0x02FF_FFFF => self.ewram.write(u32, align_addr, word),
        0x0300_0000...0x03FF_FFFF => self.iwram.write(u32, align_addr, word),
        0x0400_0000...0x0400_03FE => io.write32(self, align_addr, word),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.write(u32, align_addr, word),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.write(u32, align_addr, word),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.write(u32, align_addr, word),
        0x0E00_0000...0x0FFF_FFFF => self.pak.backup.write(address, @truncate(u8, rotr(u32, word, 8 * (address & 3)))),

        else => undWrite("Tried to write 0x{X:0>8} to 0x{X:0>8}", .{ word, address }),
    }
}

pub fn read16(self: *const Self, address: u32) u16 {
    const align_addr = address & 0xFFFF_FFFE; // Force Aligned

    return switch (address) {
        // General Internal Memory
        0x0000_0000...0x0000_3FFF => self.bios.read(u16, align_addr),
        0x0200_0000...0x02FF_FFFF => self.ewram.read(u16, align_addr),
        0x0300_0000...0x03FF_FFFF => self.iwram.read(u16, align_addr),
        0x0400_0000...0x0400_03FE => io.read16(self, align_addr),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.read(u16, align_addr),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.read(u16, align_addr),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.read(u16, align_addr),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.read(u16, align_addr),
        0x0A00_0000...0x0BFF_FFFF => self.pak.read(u16, align_addr),
        0x0C00_0000...0x0DFF_FFFF => self.pak.read(u16, align_addr),
        0x0E00_0000...0x0FFF_FFFF => @as(u16, self.pak.backup.read(address)) * 0x0101,

        else => undRead("Tried to read from 0x{X:0>8}", .{address}),
    };
}

pub fn write16(self: *Self, address: u32, halfword: u16) void {
    const align_addr = address & 0xFFFF_FFFE;

    switch (address) {
        // General Internal Memory
        0x0200_0000...0x02FF_FFFF => self.ewram.write(u16, align_addr, halfword),
        0x0300_0000...0x03FF_FFFF => self.iwram.write(u16, align_addr, halfword),
        0x0400_0000...0x0400_03FE => io.write16(self, align_addr, halfword),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.write(u16, align_addr, halfword),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.write(u16, align_addr, halfword),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.write(u16, align_addr, halfword),
        0x0800_00C4, 0x0800_00C6, 0x0800_00C8 => log.warn("Tried to write 0x{X:0>4} to GPIO", .{halfword}),

        // External Memory (Game Pak)
        0x0E00_0000...0x0FFF_FFFF => {
            self.pak.backup.write(address, @truncate(u8, rotr(u16, halfword, 8 * (address & 1))));
        },

        else => undWrite("Tried to write 0x{X:0>4} to 0x{X:0>8}", .{ halfword, address }),
    }
}

pub fn read8(self: *const Self, address: u32) u8 {
    return switch (address) {
        // General Internal Memory
        0x0000_0000...0x0000_3FFF => self.bios.read(u8, address),
        0x0200_0000...0x02FF_FFFF => self.ewram.read(u8, address),
        0x0300_0000...0x03FF_FFFF => self.iwram.read(u8, address),
        0x0400_0000...0x0400_03FE => io.read8(self, address),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.read(u8, address),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.read(u8, address),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.read(u8, address),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.read(u8, address),
        0x0A00_0000...0x0BFF_FFFF => self.pak.read(u8, address),
        0x0C00_0000...0x0DFF_FFFF => self.pak.read(u8, address),
        0x0E00_0000...0x0FFF_FFFF => self.pak.backup.read(address),

        else => undRead("Tried to read from 0x{X:0>2}", .{address}),
    };
}

pub fn write8(self: *Self, address: u32, byte: u8) void {
    switch (address) {
        // General Internal Memory
        0x0200_0000...0x02FF_FFFF => self.ewram.write(u8, address, byte),
        0x0300_0000...0x03FF_FFFF => self.iwram.write(u8, address, byte),
        0x0400_0000...0x0400_03FE => io.write8(self, address, byte),
        0x0400_0410 => log.info("Ignored write of 0x{X:0>2} to 0x{X:0>8}", .{ byte, address }),

        // External Memory (Game Pak)
        0x0E00_0000...0x0FFF_FFFF => self.pak.backup.write(address, byte),
        else => undWrite("Tried to write 0x{X:0>2} to 0x{X:0>8}", .{ byte, address }),
    }
}

fn undRead(comptime format: []const u8, args: anytype) u8 {
    if (panic_on_und_bus) std.debug.panic(format, args) else log.warn(format, args);
    return 0;
}

fn undWrite(comptime format: []const u8, args: anytype) void {
    if (panic_on_und_bus) std.debug.panic(format, args) else log.warn(format, args);
}
