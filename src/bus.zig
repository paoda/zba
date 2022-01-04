const std = @import("std");

const Io = @import("bus/io.zig").Io;
const Bios = @import("bus/bios.zig").Bios;
const GamePak = @import("bus/pak.zig").GamePak;
const Ppu = @import("ppu.zig").Ppu;

const Allocator = std.mem.Allocator;

pub const Bus = struct {
    pak: GamePak,
    bios: Bios,
    ppu: Ppu,
    io: Io,

    pub fn init(alloc: Allocator, path: []const u8) !@This() {
        return @This(){
            .pak = try GamePak.init(alloc, path),
            .bios = try Bios.init(alloc, "./bin/gba_bios.bin"), // TODO: don't hardcode this + bundle open-sorce Boot ROM
            .ppu = try Ppu.init(alloc),
            .io = Io.init(),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.pak.deinit();
        self.bios.deinit();
        self.ppu.deinit();
    }

    pub fn read32(self: *const @This(), addr: u32) u32 {
        return switch (addr) {
            // General Internal Memory
            0x0000_0000...0x0000_3FFF => self.bios.get32(@as(usize, addr)),
            0x0200_0000...0x0203_FFFF => std.debug.panic("[Bus:32] read from 0x{X:} in IWRAM", .{addr}),
            0x0300_0000...0x0300_7FFF => std.debug.panic("[Bus:32] read from 0x{X:} in EWRAM", .{addr}),
            0x0400_0000...0x0400_03FE => self.read32(addr),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("[Bus:32] read from 0x{X:} in BG/OBJ Palette RAM", .{addr}),
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

    pub fn write32(self: *@This(), addr: u32, word: u32) void {
        // TODO: write32 can write to GamePak Flash

        switch (addr) {
            // General Internal Memory
            0x0200_0000...0x0203_FFFF => std.debug.panic("[Bus:32] wrote 0x{X:} to 0x{X:} in IWRAM", .{ word, addr }),
            0x0300_0000...0x0300_7FFF => std.debug.panic("[Bus:32] wrote 0x{X:} to 0x{X:} in EWRAM", .{ word, addr }),
            0x0400_0000...0x0400_03FE => std.debug.panic("[Bus:32] wrote 0x{X:} to 0x{X:} in I/O", .{ word, addr }),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("[Bus:32] wrote 0x{X:} to 0x{X:} in BG/OBJ Palette RAM", .{ word, addr }),
            0x0600_0000...0x0601_7FFF => self.ppu.vram.set32(@as(usize, addr - 0x0600_0000), word),
            0x0700_0000...0x0700_03FF => std.debug.panic("[Bus:32] wrote 0x{X:} to 0x{X:} in OAM", .{ word, addr }),

            else => std.log.warn("[Bus:32] ZBA tried to write 0x{X:} to 0x{X:}", .{ word, addr }),
        }
    }

    pub fn read16(self: *const @This(), addr: u32) u16 {
        return switch (addr) {
            // General Internal Memory
            0x0000_0000...0x0000_3FFF => self.bios.get16(@as(usize, addr)),
            0x0200_0000...0x0203_FFFF => std.debug.panic("[Bus:16] read from 0x{X:} in IWRAM", .{addr}),
            0x0300_0000...0x0300_7FFF => std.debug.panic("[Bus:16] read from 0x{X:} in EWRAM", .{addr}),
            0x0400_0000...0x0400_03FE => self.io.read16(addr),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("[Bus:16] read from 0x{X:} in BG/OBJ Palette RAM", .{addr}),
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

    pub fn write16(self: *@This(), addr: u32, halfword: u16) void {
        // TODO: write16 can write to GamePak Flash
        switch (addr) {
            // General Internal Memory
            0x0200_0000...0x0203_FFFF => std.debug.panic("[Bus:16] write 0x{X:} to 0x{X:} in IWRAM", .{ halfword, addr }),
            0x0300_0000...0x0300_7FFF => std.debug.panic("[Bus:16] write 0x{X:} to 0x{X:} in EWRAM", .{ halfword, addr }),
            0x0400_0000...0x0400_03FE => self.io.write16(addr, halfword),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("[Bus:16] write 0x{X:} to 0x{X:} in BG/OBJ Palette RAM", .{ halfword, addr }),
            0x0600_0000...0x0601_7FFF => self.ppu.vram.set16(@as(usize, addr - 0x0600_0000), halfword),
            0x0700_0000...0x0700_03FF => std.debug.panic("[Bus:16] write 0x{X:} to 0x{X:} in OAM", .{ halfword, addr }),

            else => std.log.warn("[Bus:16] ZBA tried to write 0x{X:} to 0x{X:}", .{ halfword, addr }),
        }
    }

    pub fn read8(self: *const @This(), addr: u32) u8 {
        return switch (addr) {
            // General Internal Memory
            0x0000_0000...0x0000_3FFF => self.bios.get8(@as(usize, addr)),
            0x0200_0000...0x0203_FFFF => std.debug.panic("[Bus:8] read from 0x{X:} in IWRAM", .{addr}),
            0x0300_0000...0x0300_7FFF => std.debug.panic("[Bus:8] read from 0x{X:} in EWRAM", .{addr}),
            0x0400_0000...0x0400_03FE => self.io.read8(addr),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("[Bus:8] read from 0x{X:} in BG/OBJ Palette RAM", .{addr}),
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

    pub fn write8(_: *@This(), addr: u32, byte: u8) void {
        switch (addr) {
            // General Internal Memory
            0x0200_0000...0x0203_FFFF => std.debug.panic("[Bus:8] write 0x{X:} to 0x{X:} in IWRAM", .{ byte, addr }),
            0x0300_0000...0x0300_7FFF => std.debug.panic("[Bus:8] write 0x{X:} to 0x{X:} in EWRAM", .{ byte, addr }),
            0x0400_0000...0x0400_03FE => std.debug.panic("[Bus:8] write 0x{X:} to 0x{X:} in I/O", .{ byte, addr }),

            // External Memory (Game Pak)
            0x0E00_0000...0x0E00_FFFF => std.debug.panic("[Bus:8] write 0x{X:} to 0x{X:} in Game Pak SRAM", .{ byte, addr }),
            else => std.log.warn("[Bus:8] ZBA tried to write 0x{X:} to 0x{X:}", .{ byte, addr }),
        }
    }
};
