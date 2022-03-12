const std = @import("std");
const io = @import("bus/io.zig");

const EventKind = @import("scheduler.zig").EventKind;
const Scheduler = @import("scheduler.zig").Scheduler;

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.PPU);

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

    scanline_sprites: [128]?Sprite,
    scanline_buf: [width]?u16,

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

            .scanline_buf = [_]?u16{null} ** width,
            .scanline_sprites = [_]?Sprite{null} ** 128,
        };
    }

    pub fn deinit(self: Self) void {
        self.alloc.free(self.framebuf);
        self.vram.deinit();
        self.palette.deinit();
    }

    pub fn setBgOffsets(self: *Self, comptime n: u3, word: u32) void {
        self.bg[n].hofs.raw = @truncate(u16, word);
        self.bg[n].vofs.raw = @truncate(u16, word >> 16);
    }

    pub fn setAdjCnts(self: *Self, comptime n: u3, word: u32) void {
        self.bg[n].cnt.raw = @truncate(u16, word);
        self.bg[n + 1].cnt.raw = @truncate(u16, word >> 16);
    }

    /// Search OAM for Sprites that might be rendered on this scanline
    fn fetchSprites(self: *Self) void {
        const y = self.vcount.scanline.read();

        var i: usize = 0;
        search: while (i < self.oam.buf.len) : (i += 8) {
            // Attributes in OAM are 6 bytes long, with 2 bytes of padding
            // Grab Attributes from OAM
            const attr0 = @bitCast(Attr0, self.oam.get16(i));
            const attr1 = @bitCast(Attr1, self.oam.get16(i + 2));
            const attr2 = @bitCast(Attr2, self.oam.get16(i + 4));
            const sprite = Sprite.init(attr0, attr1, attr2);

            // Only consider enabled sprites
            if (sprite.isDisabled()) continue;

            // Determine sprite bounds
            // We only care about the Y axis since that value remains constant
            const start = sprite.y();
            const end = start + sprite.height;

            if (start <= y and y < end) {
                for (self.scanline_sprites) |*maybe_sprite| {
                    if (maybe_sprite.* == null) {
                        maybe_sprite.* = sprite;
                        continue :search;
                    }
                }

                log.err("Found more than 128 sprites in OAM Search", .{});
                unreachable; // TODO: Is this truly unreachable?
            }
        }
    }

    fn drawSprites(self: *Self, prio: u2) void {
        // Object VRAM 3rd and 4th (0-indexed) charblocks
        const char_base = 0x4000 * 4;
        const scanline = self.vcount.scanline.read();

        var i: u32 = 0;
        while (i < width) : (i += 1) {
            // Exit early if a pixel is already here
            if (self.scanline_buf[i] != null) continue;

            const x = i;
            const y = scanline;

            for (self.scanline_sprites) |maybe_sprite| {
                if (maybe_sprite) |sprite| {
                    if (sprite.priority() != prio) continue;

                    const start = sprite.x();
                    const end = start + sprite.width;

                    if (start <= x and x < end) {

                        // FIXME: We branch on this condition quite a lot
                        const is_8bpp = sprite.is_8bpp();

                        // Y and X coordinates within the context of a singular 8x8 tile
                        const tile_y: u16 = (y - sprite.y()) ^ if (sprite.v_flip()) (sprite.height - 1) else 0;
                        const tile_x = (x - sprite.x()) ^ if (sprite.h_flip()) (sprite.width - 1) else 0;

                        const tile_id: u32 = sprite.tile_id();
                        const tile_row_offset: u32 = if (is_8bpp) 8 else 4;
                        const tile_len: u32 = if (is_8bpp) 0x40 else 0x20;

                        const row = tile_y % 8;
                        const col = tile_x % 8;

                        const tile_base: u32 = char_base + (0x20 * tile_id) + (tile_row_offset * row) + if (is_8bpp) col else col / 2;

                        var tile_offset = (tile_x / 8) * tile_len;
                        if (self.dispcnt.obj_mapping.read()) {
                            // One Dimensional
                            tile_offset += (tile_y / 8) * tile_len * (sprite.width / 8);
                        } else {
                            // Two Dimensional
                            // TODO: This doesn't work
                            tile_offset += (tile_y / 8) * tile_len * 0x20;
                        }

                        const tile = self.vram.buf[tile_base + tile_offset];

                        const pal_id: u16 = if (!is_8bpp) blk: {
                            const nybble_tile = if (col & 1 == 1) tile >> 4 else tile & 0xF;
                            if (nybble_tile == 0) break :blk 0;

                            const pal_bank = @as(u8, sprite.pal_bank()) << 4;
                            break :blk pal_bank | nybble_tile;
                        } else tile;

                        // Sprite Palette starts at 0x0500_0200
                        if (pal_id != 0) self.scanline_buf[i] = self.palette.get16(0x200 + pal_id * 2);
                    }
                } else break;
            }
        }
    }

    fn drawBackround(self: *Self, comptime n: u3) void {
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

        const vofs: u32 = self.bg[n].vofs.offset.read();
        const hofs: u32 = self.bg[n].hofs.offset.read();

        const y = vofs + self.vcount.scanline.read();

        var i: u32 = 0;
        while (i < width) : (i += 1) {
            // Exit early if a pixel is already here
            if (self.scanline_buf[i] != null) continue;

            const x = hofs + i;

            // Grab the Screen Entry from VRAM
            const entry_addr = screen_base + tilemapOffset(size, x, y);
            const entry = @bitCast(ScreenEntry, self.vram.get16(entry_addr));

            // Calculate the Address of the Tile in the designated Charblock
            // We also take this opportunity to flip tiles if necessary
            const tile_id: u32 = entry.tile_id.read();
            const row = if (entry.v_flip.read()) 7 - (y % 8) else y % 8; // Determine on which row in a tile we're on
            const tile_addr = char_base + (tile_len * tile_id) + (tile_row_offset * row);

            // Calculate on which column in a tile we're on
            // Similarly to when we calculated the row, if we're in 4bpp we want to account
            // for 1 byte consisting of two pixels
            const col = if (entry.h_flip.read()) 7 - (x % 8) else x % 8;
            const tile = self.vram.buf[tile_addr + if (is_8bpp) col else col / 2];

            // If we're in 8bpp, then the tile value is an index into the palette,
            // If we're in 4bpp, we have to account for a pal bank value in the Screen entry
            // and then we can index the palette
            const pal_id = if (!is_8bpp) blk: {
                const nybble_tile = if (col & 1 == 1) tile >> 4 else tile & 0xF;
                if (nybble_tile == 0) break :blk 0;

                const pal_bank: u16 = @as(u8, entry.palette_bank.read()) << 4;
                break :blk pal_bank | nybble_tile;
            } else tile;

            if (pal_id != 0) self.scanline_buf[i] = self.palette.get16(pal_id * 2);
        }
    }

    pub fn drawScanline(self: *Self) void {
        const bg_mode = self.dispcnt.bg_mode.read();
        const bg_enable = self.dispcnt.bg_enable.read();
        const obj_enable = self.dispcnt.obj_enable.read();
        const scanline = self.vcount.scanline.read();

        switch (bg_mode) {
            0x0 => {
                const start = framebuf_pitch * @as(usize, scanline);

                self.fetchSprites();

                var i: usize = 0;
                while (i < 4) : (i += 1) {
                    // Draw Sprites Here
                    if (obj_enable) self.drawSprites(@truncate(u2, i));
                    if (i == self.bg[0].cnt.priority.read() and bg_enable & 1 == 1) self.drawBackround(0);
                    if (i == self.bg[1].cnt.priority.read() and bg_enable >> 1 & 1 == 1) self.drawBackround(1);
                    if (i == self.bg[2].cnt.priority.read() and bg_enable >> 2 & 1 == 1) self.drawBackround(2);
                    if (i == self.bg[3].cnt.priority.read() and bg_enable >> 3 & 1 == 1) self.drawBackround(3);
                }

                // Copy Drawn Scanline to Frame Buffer
                // If there are any nulls present in self.scanline_buf it means that no background drew a pixel there, so draw backdrop
                for (self.scanline_buf) |maybe_px, j| {
                    const bgr555 = if (maybe_px) |px| px else self.palette.getBackdrop();

                    self.framebuf[(start + j * 2 + 1)] = @truncate(u8, bgr555 >> 8);
                    self.framebuf[(start + j * 2 + 0)] = @truncate(u8, bgr555);
                }

                // Reset Scanline Buffer
                std.mem.set(?u16, &self.scanline_buf, null);
                // Reset List of Sprites
                std.mem.set(?Sprite, &self.scanline_sprites, null);
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
                    const id = @as(u16, byte) * 2;
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

    fn getBackdrop(self: *const Self) u16 {
        return self.get16(0);
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

const Sprite = struct {
    const Self = @This();

    attr0: Attr0,
    attr1: Attr1,
    attr2: Attr2,

    width: u16,
    height: u16,

    fn init(attr0: Attr0, attr1: Attr1, attr2: Attr2) Self {
        const d = spriteDimensions(attr0.shape.read(), attr1.size.read());

        return .{
            .attr0 = attr0,
            .attr1 = attr1,
            .attr2 = attr2,
            .width = d[0],
            .height = d[1],
        };
    }

    inline fn x(self: *const Self) u16 {
        return self.attr1.x.read();
    }

    inline fn y(self: *const Self) u8 {
        return self.attr0.y.read();
    }

    inline fn is_8bpp(self: *const Self) bool {
        return self.attr0.is_8bpp.read();
    }

    inline fn shape(self: *const Self) u2 {
        return self.attr0.shape.read();
    }

    inline fn size(self: *const Self) u2 {
        return self.attr1.size.read();
    }

    inline fn tile_id(self: *const Self) u10 {
        return self.attr2.tile_id.read();
    }

    inline fn pal_bank(self: *const Self) u4 {
        return self.attr2.pal_bank.read();
    }

    inline fn h_flip(self: *const Self) bool {
        return self.attr1.h_flip.read();
    }

    inline fn v_flip(self: *const Self) bool {
        return self.attr1.v_flip.read();
    }

    inline fn priority(self: *const Self) u2 {
        return self.attr2.rel_prio.read();
    }

    inline fn isDisabled(self: *const Self) bool {
        return self.attr0.disabled.read();
    }
};

const Attr0 = extern union {
    y: Bitfield(u16, 0, 8),
    rot_scaling: Bit(u16, 8), // This SBZ
    disabled: Bit(u16, 9),
    mode: Bitfield(u16, 10, 2),
    mosaic: Bit(u16, 12),
    is_8bpp: Bit(u16, 13),
    shape: Bitfield(u16, 14, 2),
    raw: u16,
};

const Attr1 = extern union {
    x: Bitfield(u16, 0, 9),
    h_flip: Bit(u16, 12),
    v_flip: Bit(u16, 13),
    size: Bitfield(u16, 14, 2),
    raw: u16,
};

const Attr2 = extern union {
    tile_id: Bitfield(u16, 0, 10),
    rel_prio: Bitfield(u16, 10, 2),
    pal_bank: Bitfield(u16, 12, 4),
};

fn spriteDimensions(shape: u2, size: u2) [2]u16 {
    @setRuntimeSafety(false);

    return switch (shape) {
        0b00 => switch (size) {
            // Square
            0b00 => [_]u16{ 8, 8 },
            0b01 => [_]u16{ 16, 16 },
            0b10 => [_]u16{ 32, 32 },
            0b11 => [_]u16{ 64, 64 },
        },
        0b01 => switch (size) {
            0b00 => [_]u16{ 16, 8 },
            0b01 => [_]u16{ 32, 8 },
            0b10 => [_]u16{ 32, 16 },
            0b11 => [_]u16{ 64, 32 },
        },
        0b10 => switch (size) {
            0b00 => [_]u16{ 8, 16 },
            0b01 => [_]u16{ 8, 32 },
            0b10 => [_]u16{ 16, 32 },
            0b11 => [_]u16{ 32, 64 },
        },
        else => std.debug.panic("{} is an invalid sprite shape", .{shape}),
    };
}
