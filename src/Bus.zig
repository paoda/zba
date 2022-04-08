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

pub fn read32(self: *const Self, addr: u32) u32 {
    return switch (addr) {
        // General Internal Memory
        0x0000_0000...0x0000_3FFF => self.bios.get32(addr),
        0x0200_0000...0x02FF_FFFF => self.ewram.get32(addr & 0x3FFFF),
        0x0300_0000...0x03FF_FFFF => self.iwram.get32(addr & 0x7FFF),
        0x0400_0000...0x0400_03FE => io.read32(self, addr),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.get32(addr & 0x3FF),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.read(u32, addr),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.get32(addr & 0x3FF),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get32(addr - 0x0800_0000),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get32(addr - 0x0A00_0000),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get32(addr - 0x0C00_0000),

        else => undRead("Tried to read from 0x{X:0>8}", .{addr}),
    };
}

pub fn write32(self: *Self, addr: u32, word: u32) void {
    // TODO: write32 can write to GamePak Flash

    switch (addr) {
        // General Internal Memory
        0x0200_0000...0x02FF_FFFF => self.ewram.set32(addr & 0x3FFFF, word),
        0x0300_0000...0x03FF_FFFF => self.iwram.set32(addr & 0x7FFF, word),
        0x0400_0000...0x0400_03FE => io.write32(self, addr, word),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.set32(addr & 0x3FF, word),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.write(u32, addr, word),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.set32(addr & 0x3FF, word),

        else => undWrite("Tried to write 0x{X:0>8} to 0x{X:0>8}", .{ word, addr }),
    }
}

pub fn read16(self: *const Self, addr: u32) u16 {
    return switch (addr) {
        // General Internal Memory
        0x0000_0000...0x0000_3FFF => self.bios.get16(addr),
        0x0200_0000...0x02FF_FFFF => self.ewram.get16(addr & 0x3FFFF),
        0x0300_0000...0x03FF_FFFF => self.iwram.get16(addr & 0x7FFF),
        0x0400_0000...0x0400_03FE => io.read16(self, addr),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.get16(addr & 0x3FF),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.read(u16, addr),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.get16(addr & 0x3FF),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get16(addr - 0x0800_0000),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get16(addr - 0x0A00_0000),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get16(addr - 0x0C00_0000),

        else => undRead("Tried to read from 0x{X:0>8}", .{addr}),
    };
}

pub fn write16(self: *Self, addr: u32, halfword: u16) void {
    // TODO: write16 can write to GamePak Flash
    switch (addr) {
        // General Internal Memory
        0x0200_0000...0x02FF_FFFF => self.ewram.set16(addr & 0x3FFFF, halfword),
        0x0300_0000...0x03FF_FFFF => self.iwram.set16(addr & 0x7FFF, halfword),
        0x0400_0000...0x0400_03FE => io.write16(self, addr, halfword),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.set16(addr & 0x3FF, halfword),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.write(u16, addr, halfword),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.set16(addr & 0x3FF, halfword),
        0x0800_00C4, 0x0800_00C6, 0x0800_00C8 => log.warn("Tried to write 0x{X:0>4} to GPIO", .{halfword}),

        else => undWrite("Tried to write 0x{X:0>4} to 0x{X:0>8}", .{ halfword, addr }),
    }
}

pub fn read8(self: *const Self, addr: u32) u8 {
    return switch (addr) {
        // General Internal Memory
        0x0000_0000...0x0000_3FFF => self.bios.get8(addr),
        0x0200_0000...0x02FF_FFFF => self.ewram.get8(addr & 0x3FFFF),
        0x0300_0000...0x03FF_FFFF => self.iwram.get8(addr & 0x7FFF),
        0x0400_0000...0x0400_03FE => io.read8(self, addr),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.get8(addr & 0x3FF),
        0x0600_0000...0x06FF_FFFF => self.ppu.vram.read(u8, addr),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.get8(addr & 0x3FF),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get8(addr - 0x0800_0000),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get8(addr - 0x0A00_0000),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get8(addr - 0x0C00_0000),
        0x0E00_0000...0x0E00_FFFF => self.pak.backup.get8(addr & 0xFFFF),

        else => undRead("Tried to read from 0x{X:0>2}", .{addr}),
    };
}

pub fn write8(self: *Self, addr: u32, byte: u8) void {
    switch (addr) {
        // General Internal Memory
        0x0200_0000...0x02FF_FFFF => self.ewram.set8(addr & 0x3FFFF, byte),
        0x0300_0000...0x03FF_FFFF => self.iwram.set8(addr & 0x7FFF, byte),
        0x0400_0000...0x0400_03FE => io.write8(self, addr, byte),
        0x0400_0410 => log.info("Ignored write of 0x{X:0>2} to 0x{X:0>8}", .{ byte, addr }),

        // External Memory (Game Pak)
        0x0E00_0000...0x0E00_FFFF => self.pak.backup.set8(addr & 0xFFFF, byte),
        else => undWrite("Tried to write 0x{X:0>2} to 0x{X:0>8}", .{ byte, addr }),
    }
}

fn undRead(comptime format: []const u8, args: anytype) u8 {
    if (panic_on_und_bus) std.debug.panic(format, args) else log.warn(format, args);
    return 0;
}

fn undWrite(comptime format: []const u8, args: anytype) void {
    if (panic_on_und_bus) std.debug.panic(format, args) else log.warn(format, args);
}
