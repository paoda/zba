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

    bg: [4]Background,

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
            .bg = [_]Background{Background.init()} ** 4,
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

    fn drawBackround(self: *Self, comptime n: u3, scanline: u32) void {
        // The Current Scanline which will be copied into
        // the Framebuffer
        const start = framebuf_pitch * @as(usize, scanline);
        var scanline_buf = std.mem.zeroes([framebuf_pitch]u8);

        // A Tile in a charblock is a byte, while a Screen Entry is a halfword
        const charblock_len: u32 = 0x4000;
        const screenblock_len: u32 = 0x800;

        const cbb: u2 = self.bg[n].cnt.char_base.read(); // Char Block Base
        const sbb: u5 = self.bg[n].cnt.screen_base.read(); // Screen Block Base
        const is_8bpp: bool = self.bg[n].cnt.colour_mode.read(); // Colour Mode
        const size: u2 = self.bg[n].cnt.size.read(); // Background Size

        // In 4bpp: 1 byte represents two pixels so the length is (8 x 8) / 2
        // In 8bpp: 1 byte represents one pixel so the length is 8 x 8
        const tile_len = if (is_8bpp) @as(u32, 0x40) else 0x20;
        const tile_row_offset = if (is_8bpp) @as(u32, 0x8) else 0x4;

        // 0x0600_000 is implied because we can access VRAM without the Bus
        const char_base: u32 = charblock_len * @as(u32, cbb);
        const screen_base: u32 = screenblock_len * @as(u32, sbb);

        const vofs = self.bg[n].vofs.offset.read();
        const hofs = self.bg[n].hofs.offset.read();

        const y = vofs + scanline;

        var i: u32 = 0;
        while (i < width) : (i += 1) {
            const x = hofs + i;

            // Grab the Screen Entry from VRAM
            const entry_addr = screen_base + tilemapOffset(size, x, y);
            const entry = @bitCast(ScreenEntry, self.vram.get16(entry_addr));

            // Calculate the Address of the Tile in the designated Charblock
            // We also take this opportunity to flip tiles if necessary
            const tile_id: u32 = entry.tile_id.read();
            const row = if (entry.h_flip.read()) 7 - (y % 8) else y % 8; // Determine on which row in a tile we're on
            const tile_addr = char_base + (tile_len * tile_id) + (tile_row_offset * row);

            // Calculate on which column in a tile we're on
            // Similarly to when we calculated the row, if we're in 4bpp we want to account
            // for 1 byte consisting of two pixels
            const col = if (entry.v_flip.read()) 7 - (x % 8) else x % 8;
            var tile = self.vram.buf[tile_addr + if (is_8bpp) col else col / 2];

            // If we're in 8bpp, then the tile value is an index into the palette,
            // If we're in 4bpp, we have to account for a pal bank value in the Screen entry
            // and then we can index the palette
            const pal_id = if (!is_8bpp) blk: {
                tile = if (col & 1 == 1) tile >> 4 else tile & 0xF;
                const pal_bank: u8 = @as(u8, entry.palette_bank.read()) << 4;
                break :blk pal_bank | tile;
            } else tile;

            std.mem.copy(u8, scanline_buf[i * 2 ..][0..2], self.palette.buf[pal_id * 2 ..][0..2]);
        }

        std.mem.copy(u8, self.framebuf[start..][0..framebuf_pitch], &scanline_buf);
    }

    pub fn drawScanline(self: *Self) void {
        const bg_mode = self.dispcnt.bg_mode.read();
        const bg_enable = self.dispcnt.bg_enable.read();
        const scanline = self.vcount.scanline.read();

        switch (bg_mode) {
            0x0 => {
                var i: usize = 0;
                while (i < 4) : (i += 1) {
                    if (i == self.bg[0].cnt.priority.read() and bg_enable & 1 == 1) self.drawBackround(0, scanline);
                    if (i == self.bg[1].cnt.priority.read() and bg_enable >> 1 & 1 == 1) self.drawBackround(1, scanline);
                    if (i == self.bg[2].cnt.priority.read() and bg_enable >> 2 & 1 == 1) self.drawBackround(2, scanline);
                    if (i == self.bg[3].cnt.priority.read() and bg_enable >> 3 & 1 == 1) self.drawBackround(3, scanline);
                }
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

    fn tilemapOffset(size: u2, x: u32, y: u32) u32 {
        // Current Row: (y % PIXEL_COUNT) / 8
        // Current COlumn: (x % PIXEL_COUNT) / 8
        // Length of 1 row of Screen Entries: 0x40
        // Length of 1 Screen Entry: 0x2 is the size of a screen entry
        @setRuntimeSafety(false);

        return switch (size) {
            0 => (x % 256 / 8) * 2 + (y % 256 / 8) * 0x40, // 256 x 256
            1 => blk: {
                // 512 x 256
                const offset: u32 = if (x & 0x1FF > 0xFF) 0x800 else 0;
                break :blk offset + (x % 256 / 8) * 2 + (y % 256 / 8) * 0x40;
            },
            2 => blk: {
                // 256 x 512
                const offset: u32 = if (y & 0x1FF > 0xFF) 0x800 else 0;
                break :blk offset + (x % 256 / 8) * 2 + (y % 256 / 8) * 0x40;
            },
            3 => blk: {
                // 512 x 512
                const offset: u32 = if (x & 0x1FF > 0xFF) 0x800 else 0;
                const offset_2: u32 = if (y & 0x1FF > 0xFF) 0x800 else 0;
                break :blk offset + offset_2 + (x % 256 / 8) * 2 + (y % 512 / 8) * 0x40;
            },
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
