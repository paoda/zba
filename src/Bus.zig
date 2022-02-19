const std = @import("std");

const Bios = @import("bus/Bios.zig");
const Ewram = @import("bus/Ewram.zig");
const GamePak = @import("bus/GamePak.zig");
const Io = @import("bus/io.zig").Io;
const Iwram = @import("bus/Iwram.zig");
const Ppu = @import("ppu.zig").Ppu;
const Scheduler = @import("scheduler.zig").Scheduler;

const io = @import("bus/io.zig");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Bus);
const Self = @This();

pak: GamePak,
bios: Bios,
ppu: Ppu,
iwram: Iwram,
ewram: Ewram,
io: Io,

pub fn init(alloc: Allocator, sched: *Scheduler, rom_path: []const u8, maybe_bios: ?[]const u8) !Self {
    return Self{
        .pak = try GamePak.init(alloc, rom_path),
        .bios = try Bios.init(alloc, maybe_bios),
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
        0x0000_0000...0x0000_3FFF => self.bios.get32(addr),
        0x0200_0000...0x02FF_FFFF => self.ewram.get32(addr & 0x3FFFF),
        0x0300_0000...0x03FF_FFFF => self.iwram.get32(addr & 0x7FFF),
        0x0400_0000...0x0400_03FE => io.read32(self, addr),

        // Internal Display Memory
        0x0500_0000...0x05FF_FFFF => self.ppu.palette.get32(addr & 0x3FF),
        0x0600_0000...0x0601_7FFF => self.ppu.vram.get32(addr - 0x0600_0000),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.get32(addr & 0x3FF),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get32(addr - 0x0800_0000),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get32(addr - 0x0A00_0000),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get32(addr - 0x0C00_0000),

        else => blk: {
            log.warn("32-bit read from 0x{X:0>8}", .{addr});
            break :blk 0x0000_0000;
        },
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
        0x0600_0000...0x0601_7FFF => self.ppu.vram.set32(addr - 0x0600_0000, word),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.set32(addr & 0x3FF, word),

        else => log.warn("32-bit write of 0x{X:0>8} to 0x{X:0>8}", .{ word, addr }),
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
        0x0600_0000...0x0601_7FFF => self.ppu.vram.get16(addr - 0x0600_0000),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.get16(addr & 0x3FF),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get16(addr - 0x0800_0000),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get16(addr - 0x0A00_0000),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get16(addr - 0x0C00_0000),

        else => std.debug.panic("16-bit read from 0x{X:0>8}", .{addr}),
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
        0x0600_0000...0x0601_7FFF => self.ppu.vram.set16(addr - 0x0600_0000, halfword),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.set16(addr & 0x3FF, halfword),

        else => std.debug.panic("16-bit write of 0x{X:0>4} to 0x{X:0>8}", .{ halfword, addr }),
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
        0x0600_0000...0x0601_7FFF => self.ppu.vram.get8(addr - 0x0600_0000),
        0x0700_0000...0x07FF_FFFF => self.ppu.oam.get8(addr & 0x3FF),

        // External Memory (Game Pak)
        0x0800_0000...0x09FF_FFFF => self.pak.get8(addr - 0x0800_0000),
        0x0A00_0000...0x0BFF_FFFF => self.pak.get8(addr - 0x0A00_0000),
        0x0C00_0000...0x0DFF_FFFF => self.pak.get8(addr - 0x0C00_0000),
        0x0E00_0000...0x0E00_FFFF => std.debug.panic("[Bus:8] read from 0x{X:} in Game Pak SRAM", .{addr}),

        else => std.debug.panic("8-bit read from 0x{X:0>8}", .{addr}),
    };
}

pub fn write8(self: *Self, addr: u32, byte: u8) void {
    switch (addr) {
        // General Internal Memory
        0x0200_0000...0x02FF_FFFF => self.ewram.set8(addr & 0x3FFFF, byte),
        0x0300_0000...0x03FF_FFFF => self.iwram.set8(addr & 0x7FFF, byte),
        0x0400_0000...0x0400_03FE => io.write8(self, addr, byte),

        // External Memory (Game Pak)
        0x0E00_0000...0x0E00_FFFF => std.debug.panic("[Bus:8] write 0x{X:} to 0x{X:} in Game Pak SRAM", .{ byte, addr }),
        else => std.debug.panic("8-bit write of 0x{X:0>2} to 0x{X:0>8}", .{ byte, addr }),
    }
}
