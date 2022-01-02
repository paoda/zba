const std = @import("std");

const Bios = @import("bus/bios.zig").Bios;
const GamePak = @import("bus/pak.zig").GamePak;
const Allocator = std.mem.Allocator;

pub const Bus = struct {
    pak: GamePak,
    bios: Bios,

    pub fn init(alloc: Allocator, path: []const u8) !@This() {
        return @This(){
            .pak = try GamePak.init(alloc, path),
            // TODO: don't hardcode this + bundle open-sorce Boot ROM
            .bios = try Bios.init(alloc, "./bin/gba_bios.bin"),
        };
    }

    pub fn read32(self: *const @This(), addr: u32) u32 {
        return switch (addr) {
            // General Internal Memory
            0x0000_0000...0x0000_3FFF => self.bios.get32(@as(usize, addr)),
            0x0200_0000...0x0203FFFF => std.debug.panic("read32 from 0x{X:} in IWRAM", .{addr}),
            0x0300_0000...0x0300_7FFF => std.debug.panic("read32 from 0x{X:} in EWRAM", .{addr}),
            0x0400_0000...0x0400_03FE => std.debug.panic("read32 from 0x{X:} in I/O", .{addr}),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("read32 from 0x{X:} in BG/OBJ Palette RAM", .{addr}),
            0x0600_0000...0x0601_7FFF => std.debug.panic("read32 from 0x{X:} in VRAM", .{addr}),
            0x0700_0000...0x0700_03FF => std.debug.panic("read32 from 0x{X:} in OAM", .{addr}),

            // External Memory (Game Pak)
            0x0800_0000...0x09FF_FFFF => self.pak.get32(@as(usize, addr - 0x0800_0000)),
            0x0A00_0000...0x0BFF_FFFF => self.pak.get32(@as(usize, addr - 0x0A00_0000)),
            0x0C00_0000...0x0DFF_FFFF => self.pak.get32(@as(usize, addr - 0x0C00_0000)),

            else => {
                std.log.warn("ZBA tried to read32 from 0x{X:}", .{addr});
                return 0x0000_0000;
            },
        };
    }

    pub fn write32(_: *@This(), addr: u32, word: u32) void {
        // TODO: write32 can write to GamePak Flash

        switch (addr) {
            // General Internal Memory
            0x0200_0000...0x0203FFFF => std.debug.panic("write32 0x{X:} to 0x{X:} in IWRAM", .{ word, addr }),
            0x0300_0000...0x0300_7FFF => std.debug.panic("write32 0x{X:} to 0x{X:} in EWRAM", .{ word, addr }),
            0x0400_0000...0x0400_03FE => std.debug.panic("write32 0x{X:} to 0x{X:} in I/O", .{ word, addr }),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("write32 0x{X:} to 0x{X:} in BG/OBJ Palette RAM", .{ word, addr }),
            0x0600_0000...0x0601_7FFF => std.debug.panic("write32 0x{X:} to 0x{X:} in VRAM", .{ word, addr }),
            0x0700_0000...0x0700_03FF => std.debug.panic("write32 0x{X:} to 0x{X:} in OAM", .{ word, addr }),

            else => std.log.warn("ZBA tried to write32 0x{X:} to 0x{X:}", .{ word, addr }),
        }
    }

    pub fn read16(self: *const @This(), addr: u32) u16 {
        return switch (addr) {
            // General Internal Memory
            0x0000_0000...0x0000_3FFF => self.bios.get16(@as(usize, addr)),
            0x0200_0000...0x0203FFFF => std.debug.panic("read16 from 0x{X:} in IWRAM", .{addr}),
            0x0300_0000...0x0300_7FFF => std.debug.panic("read16 from 0x{X:} in EWRAM", .{addr}),
            0x0400_0000...0x0400_03FE => std.debug.panic("read16 from 0x{X:} in I/O", .{addr}),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("read16 from 0x{X:} in BG/OBJ Palette RAM", .{addr}),
            0x0600_0000...0x0601_7FFF => std.debug.panic("read16 from 0x{X:} in VRAM", .{addr}),
            0x0700_0000...0x0700_03FF => std.debug.panic("read16 from 0x{X:} in OAM", .{addr}),

            // External Memory (Game Pak)
            0x0800_0000...0x09FF_FFFF => self.pak.get16(@as(usize, addr - 0x0800_0000)),
            0x0A00_0000...0x0BFF_FFFF => self.pak.get16(@as(usize, addr - 0x0A00_0000)),
            0x0C00_0000...0x0DFF_FFFF => self.pak.get16(@as(usize, addr - 0x0C00_0000)),

            else => {
                std.log.warn("ZBA tried to read16 from 0x{X:}", .{addr});
                return 0x0000;
            },
        };
    }

    pub fn write16(_: *@This(), addr: u32, halfword: u16) void {
        // TODO: write16 can write to GamePak Flash

        switch (addr) {
            // General Internal Memory
            0x0200_0000...0x0203FFFF => std.debug.panic("write16 0x{X:} to 0x{X:} in IWRAM", .{ halfword, addr }),
            0x0300_0000...0x0300_7FFF => std.debug.panic("write16 0x{X:} to 0x{X:} in EWRAM", .{ halfword, addr }),
            0x0400_0000...0x0400_03FE => std.debug.panic("write16 0x{X:} to 0x{X:} in I/O", .{ halfword, addr }),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("write16 0x{X:} to 0x{X:} in BG/OBJ Palette RAM", .{ halfword, addr }),
            0x0600_0000...0x0601_7FFF => std.debug.panic("write16 0x{X:} to 0x{X:} in VRAM", .{ halfword, addr }),
            0x0700_0000...0x0700_03FF => std.debug.panic("write16 0x{X:} to 0x{X:} in OAM", .{ halfword, addr }),

            else => std.log.warn("ZBA tried to write16 0x{X:} to 0x{X:}", .{ halfword, addr }),
        }
    }

    pub fn read8(self: *const @This(), addr: u32) u8 {
        return switch (addr) {
            // General Internal Memory
            0x0000_0000...0x0000_3FFF => self.bios.get8(@as(usize, addr)),
            0x0200_0000...0x0203FFFF => std.debug.panic("read8 from 0x{X:} in IWRAM", .{addr}),
            0x0300_0000...0x0300_7FFF => std.debug.panic("read8 from 0x{X:} in EWRAM", .{addr}),
            0x0400_0000...0x0400_03FE => std.debug.panic("read8 from 0x{X:} in I/O", .{addr}),

            // Internal Display Memory
            0x0500_0000...0x0500_03FF => std.debug.panic("read8 from 0x{X:} in BG/OBJ Palette RAM", .{addr}),
            0x0600_0000...0x0601_7FFF => std.debug.panic("read8 from 0x{X:} in VRAM", .{addr}),
            0x0700_0000...0x0700_03FF => std.debug.panic("read8 from 0x{X:} in OAM", .{addr}),

            // External Memory (Game Pak)
            0x0800_0000...0x09FF_FFFF => self.pak.get8(@as(usize, addr - 0x0800_0000)),
            0x0A00_0000...0x0BFF_FFFF => self.pak.get8(@as(usize, addr - 0x0A00_0000)),
            0x0C00_0000...0x0DFF_FFFF => self.pak.get8(@as(usize, addr - 0x0C00_0000)),
            0x0E00_0000...0x0E00_FFFF => std.debug.panic("read8 from 0x{X:} in Game Pak SRAM", .{addr}),

            else => {
                std.log.warn("ZBA tried to read8 from 0x{X:}", .{addr});
                return 0x00;
            },
        };
    }

    pub fn write8(_: *@This(), addr: u32, byte: u8) void {
        switch (addr) {
            // General Internal Memory
            0x0200_0000...0x0203FFFF => std.debug.panic("write8 0x{X:} to 0x{X:} in IWRAM", .{ byte, addr }),
            0x0300_0000...0x0300_7FFF => std.debug.panic("write8 0x{X:} to 0x{X:} in EWRAM", .{ byte, addr }),
            0x0400_0000...0x0400_03FE => std.debug.panic("write8 0x{X:} to 0x{X:} in I/O", .{ byte, addr }),

            // External Memory (Game Pak)
            0x0E00_0000...0x0E00_FFFF => std.debug.panic("write8 0x{X:} to 0x{X:} in Game Pak SRAM", .{ byte, addr }),
            else => std.log.warn("ZBA tried to write8 0x{X:} to 0x{X:}", .{ byte, addr }),
        }
    }
};
