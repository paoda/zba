const std = @import("std");

const Bios = @import("bus/Bios.zig");
const Ewram = @import("bus/Ewram.zig");
const GamePak = @import("bus/GamePak.zig");
const Io = @import("bus/io.zig").Io;
const Iwram = @import("bus/Iwram.zig");
const Ppu = @import("ppu.zig").Ppu;
const Scheduler = @import("scheduler.zig").Scheduler;

const Allocator = std.mem.Allocator;
const Self = @This();

pak: GamePak,
bios: Bios,
ppu: Ppu,
iwram: Iwram,
ewram: Ewram,
io: Io,

pub fn init(alloc: Allocator, sched: *Scheduler, path: []const u8) !Self {
    return Self{
        .pak = try GamePak.init(alloc, path),
        .bios = try Bios.init(alloc, "./bin/gba_bios.bin"), // TODO: don't hardcode this + bundle open-sorce Boot ROM
        .ppu = try Ppu.init(alloc, sched),
        .iwram = try Iwram.init(alloc),
        .ewram = try Ewram.init(alloc),
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
        0x0000_0000...0x0000_3FFF => self.bios.get32(@as(usize, addr)),
        0x0200_0000...0x0203_FFFF => self.iwram.get32(addr - 0x0200_0000),
        0x0300_0000...0x0300_7FFF => self.ewram.get32(addr - 0x0300_0000),
        0x0400_0000...0x0400_03FE => self.io.read32(addr),

        // Internal Display Memory
        0x0500_0000...0x0500_03FF => self.ppu.palette.get32(@as(usize, addr - 0x0500_0000)),
        0x0600_0000...0x0601_7FFF => self.ppu.vram.get32(@as(usize, addr - 0x0600_0000)),
        0x0700_0000...0x0700_03FF => std.debug.panic("[Bus:32] read from 0x{X:} in OAM", .{addr}),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get32(@as(usize, addr - 0x0800_0000)),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get32(@as(usize, addr - 0x0A00_0000)),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get32(@as(usize, addr - 0x0C00_0000)),

        else => {
            std.log.warn("[Bus:32] ZBA tried to read from 0x{X:}", .{addr});
            return 0x0000_0000;
        },
    };
}

pub fn write32(self: *Self, addr: u32, word: u32) void {
    // TODO: write32 can write to GamePak Flash

    switch (addr) {
        // General Internal Memory
        0x0200_0000...0x0203_FFFF => self.iwram.set32(addr - 0x0200_0000, word),
        0x0300_0000...0x0300_7FFF => self.ewram.set32(addr - 0x0300_0000, word),
        0x0400_0000...0x0400_03FE => self.io.write32(addr, word),

        // Internal Display Memory
        0x0500_0000...0x0500_03FF => self.ppu.palette.set32(@as(usize, addr - 0x0500_0000), word),
        0x0600_0000...0x0601_7FFF => self.ppu.vram.set32(@as(usize, addr - 0x0600_0000), word),
        0x0700_0000...0x0700_03FF => std.debug.panic("[Bus:32] wrote 0x{X:} to 0x{X:} in OAM", .{ word, addr }),

        else => std.log.warn("[Bus:32] ZBA tried to write 0x{X:} to 0x{X:}", .{ word, addr }),
    }
}

pub fn read16(self: *const Self, addr: u32) u16 {
    return switch (addr) {
        // General Internal Memory
        0x0000_0000...0x0000_3FFF => self.bios.get16(@as(usize, addr)),
        0x0200_0000...0x0203_FFFF => self.iwram.get16(addr - 0x0200_0000),
        0x0300_0000...0x0300_7FFF => self.ewram.get16(addr - 0x0300_0000),
        0x0400_0000...0x0400_03FE => self.io.read16(addr),

        // Internal Display Memory
        0x0500_0000...0x0500_03FF => self.ppu.palette.get16(@as(usize, addr - 0x0500_0000)),
        0x0600_0000...0x0601_7FFF => self.ppu.vram.get16(@as(usize, addr - 0x0600_0000)),
        0x0700_0000...0x0700_03FF => std.debug.panic("[Bus:16] read from 0x{X:} in OAM", .{addr}),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get16(@as(usize, addr - 0x0800_0000)),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get16(@as(usize, addr - 0x0A00_0000)),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get16(@as(usize, addr - 0x0C00_0000)),

        else => {
            std.log.warn("[Bus:16] ZBA tried to read from 0x{X:}", .{addr});
            return 0x0000;
        },
    };
}

pub fn write16(self: *Self, addr: u32, halfword: u16) void {
    // TODO: write16 can write to GamePak Flash
    switch (addr) {
        // General Internal Memory
        0x0200_0000...0x0203_FFFF => self.iwram.set16(addr - 0x0200_0000, halfword),
        0x0300_0000...0x0300_7FFF => self.ewram.set16(addr - 0x0300_0000, halfword),
        0x0400_0000...0x0400_03FE => self.io.write16(addr, halfword),

        // Internal Display Memory
        0x0500_0000...0x0500_03FF => self.ppu.palette.set16(@as(usize, addr - 0x0500_0000), halfword),
        0x0600_0000...0x0601_7FFF => self.ppu.vram.set16(@as(usize, addr - 0x0600_0000), halfword),
        0x0700_0000...0x0700_03FF => std.debug.panic("[Bus:16] write 0x{X:} to 0x{X:} in OAM", .{ halfword, addr }),

        else => std.log.warn("[Bus:16] ZBA tried to write 0x{X:} to 0x{X:}", .{ halfword, addr }),
    }
}

pub fn read8(self: *const Self, addr: u32) u8 {
    return switch (addr) {
        // General Internal Memory
        0x0000_0000...0x0000_3FFF => self.bios.get8(@as(usize, addr)),
        0x0200_0000...0x0203_FFFF => self.iwram.get8(addr - 0x0200_0000),
        0x0300_0000...0x0300_7FFF => self.ewram.get8(addr - 0x0300_0000),
        0x0400_0000...0x0400_03FE => self.io.read8(addr),

        // Internal Display Memory
        0x0500_0000...0x0500_03FF => self.ppu.palette.get8(@as(usize, addr - 0x0500_0000)),
        0x0600_0000...0x0601_7FFF => self.ppu.vram.get8(@as(usize, addr - 0x0600_0000)),
        0x0700_0000...0x0700_03FF => std.debug.panic("[Bus:8] read from 0x{X:} in OAM", .{addr}),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get8(@as(usize, addr - 0x0800_0000)),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get8(@as(usize, addr - 0x0A00_0000)),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get8(@as(usize, addr - 0x0C00_0000)),
        0x0E00_0000...0x0E00_FFFF => std.debug.panic("[Bus:8] read from 0x{X:} in Game Pak SRAM", .{addr}),

        else => {
            std.log.warn("[Bus:8] ZBA tried to read from 0x{X:}", .{addr});
            return 0x00;
        },
    };
}

pub fn write8(self: *Self, addr: u32, byte: u8) void {
    switch (addr) {
        // General Internal Memory
        0x0200_0000...0x0203_FFFF => self.iwram.set8(addr - 0x0200_0000, byte),
        0x0300_0000...0x0300_7FFF => self.ewram.set8(addr - 0x0300_0000, byte),
        0x0400_0000...0x0400_03FE => self.io.write8(addr, byte),

        // External Memory (Game Pak)
        0x0E00_0000...0x0E00_FFFF => std.debug.panic("[Bus:8] write 0x{X:} to 0x{X:} in Game Pak SRAM", .{ byte, addr }),
        else => std.log.warn("[Bus:8] ZBA tried to write 0x{X:} to 0x{X:}", .{ byte, addr }),
    }
}
