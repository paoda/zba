const std = @import("std");
const io = @import("bus/io.zig");

const EventKind = @import("scheduler.zig").EventKind;
const Scheduler = @import("scheduler.zig").Scheduler;

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;

const Allocator = std.mem.Allocator;

pub const width = 240;
pub const height = 160;
pub const framebuf_pitch = width * @sizeOf(u16);

pub const Ppu = struct {
    const Self = @This();

    // Registers
    bg0: Background,
    bg1: Background,
    bg2: Background,
    bg3: Background,

    dispcnt: io.DisplayControl,
    dispstat: io.DisplayStatus,
    vcount: io.VCount,

    vram: Vram,
    palette: Palette,
    oam: Oam,
    sched: *Scheduler,
    framebuf: []u8,
    alloc: Allocator,

    pub fn init(alloc: Allocator, sched: *Scheduler) !Self {
        // Queue first Hblank
        sched.push(.Draw, sched.tick + (240 * 4));

        const framebuf = try alloc.alloc(u8, framebuf_pitch * height);
        std.mem.set(u8, framebuf, 0);

        return Self{
            .vram = try Vram.init(alloc),
            .palette = try Palette.init(alloc),
            .oam = try Oam.init(alloc),
            .sched = sched,
            .framebuf = framebuf,
            .alloc = alloc,

            // Registers
            .bg0 = Background.init(),
            .bg1 = Background.init(),
            .bg2 = Background.init(),
            .bg3 = Background.init(),
            .dispcnt = .{ .raw = 0x0000 },
            .dispstat = .{ .raw = 0x0000 },
            .vcount = .{ .raw = 0x0000 },
        };
    }

    pub fn deinit(self: Self) void {
        self.alloc.free(self.framebuf);
        self.vram.deinit();
        self.palette.deinit();
    }

    pub fn drawScanline(self: *Self) void {
        const bg_mode = self.dispcnt.bg_mode.read();
        const scanline = self.vcount.scanline.read();

        switch (bg_mode) {
            0x0 => {
                // A Tile is always 8x8 pixels

                // Mode 0 Implementation Assuming:
                // - Scrolling isn't a thing
                // - Bill Gates said we'll never need more than BG0

                // Write to this Scanline once we're done
                const start = framebuf_pitch * @as(usize, scanline);
                var scanline_buf = std.mem.zeroes([framebuf_pitch]u8);

                // These we can probably move to top level?
                const charblock_len: u32 = 0x4000;
                const screenblock_len: u32 = 0x800;

                const cbb: u2 = self.bg0.cnt.char_base.read(); // Char Block Base
                const sbb: u5 = self.bg0.cnt.screen_base.read(); // Screen Block Base
                const is_8bpp: bool = self.bg0.cnt.palette_type.read(); // Colour Mode
                const size: u2 = self.bg0.cnt.screen_size.read(); // Background Size

                // 0x0600_000 is implied because we can access VRAM without the Bus
                const char_base: u32 = charblock_len * @as(u32, cbb);
                const screen_base: u32 = screenblock_len * @as(u32, sbb);

                const y = @as(u32, scanline);
                var x: u32 = 0;
                while (x < width) : (x += 1) {
                    const entry_addr = screen_base + tilemapIndex(size, x, y);
                    const entry = @bitCast(ScreenEntry, @as(u16, self.vram.buf[entry_addr + 1]) << 8 | @as(u16, self.vram.buf[entry_addr]));

                    const tile_id: u32 = entry.tile_id.read();
                    const px_y = if (entry.h_flip.read()) 7 - (y % 8) else y % 8;
                    const px_x = if (entry.v_flip.read()) 7 - (x % 8) else x % 8;
                    const tile_addr = char_base + if (is_8bpp) 0x40 * tile_id + 0x8 * px_y else 0x20 * tile_id + 0x4 * px_y;

                    var tile = self.vram.buf[tile_addr + if (is_8bpp) px_x else px_x >> 1];
                    tile = if (px_x & 1 == 1) tile >> 4 else tile & 0xF;

                    const pal_bank: u8 = @as(u8, entry.palette_bank.read()) << 4;
                    const colour = pal_bank | tile;

                    std.mem.copy(u8, scanline_buf[x * 2 ..][0..2], self.palette.buf[colour * 2 ..][0..2]);
                }

                std.mem.copy(u8, self.framebuf[start..][0..framebuf_pitch], &scanline_buf);
            },
            0x3 => {
                const start = framebuf_pitch * @as(usize, scanline);
                std.mem.copy(u8, self.framebuf[start..][0..framebuf_pitch], self.vram.buf[start..][0..framebuf_pitch]);
            },
            0x4 => {
                const select = self.dispcnt.frame_select.read();
                const vram_start = width * @as(usize, scanline);
                const buf_start = vram_start * @sizeOf(u16);

                const start = vram_start + if (select) 0xA000 else @as(usize, 0);
                const end = start + width; // Each Entry is only a byte long

                // Render Current Scanline
                for (self.vram.buf[start..end]) |byte, i| {
                    const id = byte * 2;
                    const j = i * @sizeOf(u16);

                    std.mem.copy(u8, self.framebuf[(buf_start + j)..][0..2], self.palette.buf[id..][0..2]);
                }
            },
            else => std.debug.panic("[PPU] TODO: Implement BG Mode {}", .{bg_mode}),
        }
    }

    fn tilemapIndex(size: u2, x: u32, y: u32) u32 {
        return switch (size) {
            0 => (((y % 256) / 8) * 64) + (((x % 256) / 8) * 2),
            1 => (((y % 256) / 8) * 64) + (((x % 256) / 8) * 2),
            else => std.debug.panic("tile size {}", .{size}),
        };
    }
};

const Palette = struct {
    const Self = @This();

    buf: []u8,
    alloc: Allocator,

    fn init(alloc: Allocator) !Self {
        const buf = try alloc.alloc(u8, 0x400);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .alloc = alloc,
        };
    }

    fn deinit(self: Self) void {
        self.alloc.free(self.buf);
    }

    pub fn get32(self: *const Self, idx: usize) u32 {
        return (@as(u32, self.get16(idx + 2)) << 16) | @as(u32, self.get16(idx));
    }

    pub fn set32(self: *Self, idx: usize, word: u32) void {
        self.set16(idx + 2, @truncate(u16, word >> 16));
        self.set16(idx, @truncate(u16, word));
    }

    pub fn get16(self: *const Self, idx: usize) u16 {
        return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
    }

    pub fn set16(self: *Self, idx: usize, halfword: u16) void {
        self.buf[idx + 1] = @truncate(u8, halfword >> 8);
        self.buf[idx] = @truncate(u8, halfword);
    }

    pub fn get8(self: *const Self, idx: usize) u8 {
        return self.buf[idx];
    }
};

const Vram = struct {
    const Self = @This();

    buf: []u8,
    alloc: Allocator,

    fn init(alloc: Allocator) !Self {
        const buf = try alloc.alloc(u8, 0x18000);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .alloc = alloc,
        };
    }

    fn deinit(self: Self) void {
        self.alloc.free(self.buf);
    }

    pub fn get32(self: *const Self, idx: usize) u32 {
        return (@as(u32, self.get16(idx + 2)) << 16) | @as(u32, self.get16(idx));
    }

    pub fn set32(self: *Self, idx: usize, word: u32) void {
        self.set16(idx + 2, @truncate(u16, word >> 16));
        self.set16(idx, @truncate(u16, word));
    }

    pub fn get16(self: *const Self, idx: usize) u16 {
        return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
    }

    pub fn set16(self: *Self, idx: usize, halfword: u16) void {
        self.buf[idx + 1] = @truncate(u8, halfword >> 8);
        self.buf[idx] = @truncate(u8, halfword);
    }

    pub fn get8(self: *const Self, idx: usize) u8 {
        return self.buf[idx];
    }
};

const Oam = struct {
    const Self = @This();

    buf: []u8,
    alloc: Allocator,

    fn init(alloc: Allocator) !Self {
        const buf = try alloc.alloc(u8, 0x400);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .alloc = alloc,
        };
    }

    pub fn get32(self: *const Self, idx: usize) u32 {
        return (@as(u32, self.buf[idx + 3]) << 24) | (@as(u32, self.buf[idx + 2]) << 16) | (@as(u32, self.buf[idx + 1]) << 8) | (@as(u32, self.buf[idx]));
    }

    pub fn set32(self: *Self, idx: usize, word: u32) void {
        self.buf[idx + 3] = @truncate(u8, word >> 24);
        self.buf[idx + 2] = @truncate(u8, word >> 16);
        self.buf[idx + 1] = @truncate(u8, word >> 8);
        self.buf[idx] = @truncate(u8, word);
    }

    pub fn get16(self: *const Self, idx: usize) u16 {
        return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
    }

    pub fn set16(self: *Self, idx: usize, halfword: u16) void {
        self.buf[idx + 1] = @truncate(u8, halfword >> 8);
        self.buf[idx] = @truncate(u8, halfword);
    }

    pub fn get8(self: *const Self, idx: usize) u8 {
        return self.buf[idx];
    }
};

const Background = struct {
    const Self = @This();

    /// Read / Write
    cnt: io.BackgroundControl,
    /// Write Only
    hofs: io.BackgroundOffset,
    /// Write Only
    vofs: io.BackgroundOffset,

    fn init() Self {
        return .{
            .cnt = .{ .raw = 0x0000 },
            .hofs = .{ .raw = 0x0000 },
            .vofs = .{ .raw = 0x0000 },
        };
    }
};

const ScreenEntry = extern union {
    tile_id: Bitfield(u16, 0, 10),
    h_flip: Bit(u16, 10),
    v_flip: Bit(u16, 11),
    palette_bank: Bitfield(u16, 12, 4),
    raw: u16,
};
