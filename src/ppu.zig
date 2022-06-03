const std = @import("std");
const io = @import("bus/io.zig");

const EventKind = @import("scheduler.zig").EventKind;
const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.PPU);
const pollBlankingDma = @import("bus/dma.zig").pollBlankingDma;

/// This is used to generate byuu / Talurabi's Color Correction algorithm
const COLOUR_LUT = genColourLut();

pub const width = 240;
pub const height = 160;
pub const framebuf_pitch = width * @sizeOf(u32);

pub const Ppu = struct {
    const Self = @This();

    // Registers

    bg: [4]Background,
    aff: AffineBackground,

    dispcnt: io.DisplayControl,
    dispstat: io.DisplayStatus,
    vcount: io.VCount,

    vram: Vram,
    palette: Palette,
    oam: Oam,
    sched: *Scheduler,
    framebuf: FrameBuffer,
    alloc: Allocator,

    scanline_sprites: [128]?Sprite,
    scanline_buf: [width]?u16,

    pub fn init(alloc: Allocator, sched: *Scheduler) !Self {
        // Queue first Hblank
        sched.push(.Draw, 240 * 4);

        const framebufs = try alloc.alloc(u8, (framebuf_pitch * height) * 2);
        std.mem.set(u8, framebufs, 0);

        return Self{
            .vram = try Vram.init(alloc),
            .palette = try Palette.init(alloc),
            .oam = try Oam.init(alloc),
            .sched = sched,
            .framebuf = FrameBuffer.init(framebufs),
            .alloc = alloc,

            // Registers
            .bg = [_]Background{Background.init()} ** 4,
            .aff = AffineBackground.init(),
            .dispcnt = .{ .raw = 0x0000 },
            .dispstat = .{ .raw = 0x0000 },
            .vcount = .{ .raw = 0x0000 },

            .scanline_buf = [_]?u16{null} ** width,
            .scanline_sprites = [_]?Sprite{null} ** 128,
        };
    }

    pub fn deinit(self: Self) void {
        self.framebuf.deinit(self.alloc);
        self.vram.deinit();
        self.palette.deinit();
        self.oam.deinit();
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
            const attr0 = @bitCast(Attr0, self.oam.read(u16, i));

            // Only consider enabled Sprites
            if (!attr0.disabled.read()) {
                const attr1 = @bitCast(Attr1, self.oam.read(u16, i + 2));

                // When fetching sprites we only care about ones that could be rendered
                // on this scanline
                const iy = @bitCast(i8, y);

                const start = attr0.y.read();
                const istart = @bitCast(i8, start);

                const end = start +% spriteDimensions(attr0.shape.read(), attr1.size.read())[1];
                const iend = @bitCast(i8, end);

                // Sprites are expected to be able to wraparound, we perform the same check
                // for unsigned and signed values so that we handle all valid sprite positions
                if ((start <= y and y < end) or (istart <= iy and iy < iend)) {
                    for (self.scanline_sprites) |*maybe_sprite| {
                        if (maybe_sprite.* == null) {
                            maybe_sprite.* = Sprite.init(attr0, attr1, @bitCast(Attr2, self.oam.read(u16, i + 4)));
                            continue :search;
                        }
                    }

                    log.err("Found more than 128 sprites in OAM Search", .{});
                    unreachable; // TODO: Is this truly unreachable?
                }
            }
        }
    }

    /// Draw all relevant sprites on a scanline
    fn drawSprites(self: *Self, prio: u2) void {
        const char_base = 0x4000 * 4;
        const y = @bitCast(i8, self.vcount.scanline.read());

        // Loop over every fetched sprite
        sprite_loop: for (self.scanline_sprites) |maybe_sprites| {
            if (maybe_sprites) |sprite| {
                // Move on to the next sprite If its of a different priority
                if (sprite.priority() != prio) continue :sprite_loop;
                if (sprite.attr0.is_affine.read()) continue :sprite_loop; // TODO: Affine Sprites

                var i: u9 = 0;
                px_loop: while (i < sprite.width) : (i += 1) {
                    const x = (sprite.x() +% i) % 240;
                    const ix = @bitCast(i9, x);

                    // If We've already rendered a pixel here don't overwrite it
                    if (self.scanline_buf[x] != null) continue :px_loop;

                    const start = sprite.x();
                    const istart = @bitCast(i9, start);

                    const end = start +% sprite.width;
                    const iend = @bitCast(i9, end);

                    // By comparing with both signed and unsigned values we ensure that sprites
                    // are displayed in all valid (AFAIK) configuration
                    if ((start <= x and x < end) or (istart <= ix and ix < iend)) {
                        self.drawSpritePixel(char_base, sprite, ix, y);
                    }
                }
            } else break;
        }
    }

    /// Draw a Pixel of a Sprite Tile
    fn drawSpritePixel(self: *Self, char_base: u32, sprite: Sprite, x: i9, y: i8) void {
        // FIXME: We branch on this condition quite a lot
        const is_8bpp = sprite.is_8bpp();

        // std.math.absInt is branchless
        const x_diff = @bitCast(u9, std.math.absInt(x - @bitCast(i9, sprite.x())) catch unreachable);
        const y_diff = @bitCast(u8, std.math.absInt(y -% @bitCast(i8, sprite.y())) catch unreachable);

        // Note that we flip the tile_pos not the (tile_pos % 8) like we do for
        // Background Tiles. By doing this we mirror the entire sprite instead of
        // just a specific tile (see how sprite.width and sprite.height are involved)
        const tile_y = y_diff ^ if (sprite.v_flip()) (sprite.height - 1) else 0;
        const tile_x = x_diff ^ if (sprite.h_flip()) (sprite.width - 1) else 0;

        // Like in the background Tiles are 8x8 groups of pixels in 8bpp or 4bpp formats
        const tile_id = sprite.tile_id();
        const tile_row_offset: u32 = if (is_8bpp) 8 else 4;
        const tile_len: u32 = if (is_8bpp) 0x40 else 0x20;

        const row = tile_y & 7;
        const col = @truncate(u3, tile_x);

        // When calcualting the inital address, the first entry is always 0x20 * tile_id, even if it is 8bpp
        const tile_base = char_base + (0x20 * @as(u32, tile_id)) + (tile_row_offset * row) + if (is_8bpp) col else col >> 1;

        // TODO: Finish that 2D Sprites Test ROM
        const offset_base = (tile_x >> 3) * tile_len;
        const offset_offset = (tile_y >> 3) * tile_len * if (self.dispcnt.obj_mapping.read()) sprite.width >> 3 else if (is_8bpp) @as(u32, 0x10) else 0x20;

        const tile_offset = offset_base + offset_offset;
        const tile = self.vram.buf[tile_base + tile_offset];

        const pal_id: u16 = if (!is_8bpp) get4bppTilePalette(sprite.pal_bank(), col, tile) else tile;

        // Sprite Palette starts at 0x0500_0200
        if (pal_id != 0) self.scanline_buf[@bitCast(u9, x)] = self.palette.read(u16, 0x200 + pal_id * 2);
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
            const entry = @bitCast(ScreenEntry, self.vram.read(u16, entry_addr));

            // Calculate the Address of the Tile in the designated Charblock
            // We also take this opportunity to flip tiles if necessary
            const tile_id: u32 = entry.tile_id.read();
            const row = if (entry.v_flip.read()) 7 - (y % 8) else y % 8; // Determine on which row in a tile we're on
            const tile_addr = char_base + (tile_len * tile_id) + (tile_row_offset * row);

            // Calculate on which column in a tile we're on
            // Similarly to when we calculated the row, if we're in 4bpp we want to account
            // for 1 byte consisting of two pixels
            const col = @truncate(u3, x) ^ if (entry.h_flip.read()) 7 else @as(u3, 0);
            const tile = self.vram.buf[tile_addr + if (is_8bpp) col else col >> 1];

            // If we're in 8bpp, then the tile value is an index into the palette,
            // If we're in 4bpp, we have to account for a pal bank value in the Screen entry
            // and then we can index the palette
            const pal_id: u16 = if (!is_8bpp) get4bppTilePalette(entry.pal_bank.read(), col, tile) else tile;

            if (pal_id != 0) self.scanline_buf[i] = self.palette.read(u16, pal_id * 2);
        }
    }

    inline fn get4bppTilePalette(pal_bank: u4, col: u3, tile: u8) u8 {
        const nybble_tile = tile >> ((col & 1) << 2) & 0xF;
        if (nybble_tile == 0) return 0;

        return (@as(u8, pal_bank) << 4) | nybble_tile;
    }

    pub fn drawScanline(self: *Self) void {
        const bg_mode = self.dispcnt.bg_mode.read();
        const bg_enable = self.dispcnt.bg_enable.read();
        const obj_enable = self.dispcnt.obj_enable.read();
        const scanline = self.vcount.scanline.read();

        switch (bg_mode) {
            0x0 => {
                const fb_base = framebuf_pitch * @as(usize, scanline);
                if (obj_enable) self.fetchSprites();

                var layer: usize = 0;
                while (layer < 4) : (layer += 1) {
                    self.drawSprites(@truncate(u2, layer));
                    if (layer == self.bg[0].cnt.priority.read() and bg_enable & 1 == 1) self.drawBackround(0);
                    if (layer == self.bg[1].cnt.priority.read() and bg_enable >> 1 & 1 == 1) self.drawBackround(1);
                    if (layer == self.bg[2].cnt.priority.read() and bg_enable >> 2 & 1 == 1) self.drawBackround(2);
                    if (layer == self.bg[3].cnt.priority.read() and bg_enable >> 3 & 1 == 1) self.drawBackround(3);
                }

                // Copy Drawn Scanline to Frame Buffer
                // If there are any nulls present in self.scanline_buf it means that no background drew a pixel there, so draw backdrop
                for (self.scanline_buf) |maybe_px, i| {
                    const bgr555 = if (maybe_px) |px| px else self.palette.getBackdrop();
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], COLOUR_LUT[bgr555 & 0x7FFF]);
                }

                // Reset Current Scanline Pixel Buffer and list of fetched sprites
                // in prep for next scanline
                std.mem.set(?u16, &self.scanline_buf, null);
                std.mem.set(?Sprite, &self.scanline_sprites, null);
            },
            0x1 => {
                const fb_base = framebuf_pitch * @as(usize, scanline);
                if (obj_enable) self.fetchSprites();

                var layer: usize = 0;
                while (layer < 4) : (layer += 1) {
                    self.drawSprites(@truncate(u2, layer));
                    if (layer == self.bg[0].cnt.priority.read() and bg_enable & 1 == 1) self.drawBackround(0);
                    if (layer == self.bg[1].cnt.priority.read() and bg_enable >> 1 & 1 == 1) self.drawBackround(1);
                    // TODO: Implement Affine BG2
                }

                // Copy Drawn Scanline to Frame Buffer
                // If there are any nulls present in self.scanline_buf it means that no background drew a pixel there, so draw backdrop
                for (self.scanline_buf) |maybe_px, i| {
                    const bgr555 = if (maybe_px) |px| px else self.palette.getBackdrop();
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], COLOUR_LUT[bgr555 & 0x7FFF]);
                }

                // Reset Current Scanline Pixel Buffer and list of fetched sprites
                // in prep for next scanline
                std.mem.set(?u16, &self.scanline_buf, null);
                std.mem.set(?Sprite, &self.scanline_sprites, null);
            },
            0x2 => {
                const fb_base = framebuf_pitch * @as(usize, scanline);
                if (obj_enable) self.fetchSprites();

                var layer: usize = 0;
                while (layer < 4) : (layer += 1) {
                    self.drawSprites(@truncate(u2, layer));
                    // TODO: Implement Affine BG2, BG3
                }

                // Copy Drawn Scanline to Frame Buffer
                // If there are any nulls present in self.scanline_buf it means that no background drew a pixel there, so draw backdrop
                for (self.scanline_buf) |maybe_px, i| {
                    const bgr555 = if (maybe_px) |px| px else self.palette.getBackdrop();
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], COLOUR_LUT[bgr555 & 0x7FFF]);
                }

                // Reset Current Scanline Pixel Buffer and list of fetched sprites
                // in prep for next scanline
                std.mem.set(?u16, &self.scanline_buf, null);
                std.mem.set(?Sprite, &self.scanline_sprites, null);
            },
            0x3 => {
                const vram_base = width * @sizeOf(u16) * @as(usize, scanline);
                const fb_base = framebuf_pitch * @as(usize, scanline);

                var i: usize = 0;
                while (i < width) : (i += 1) {
                    const bgr555 = self.vram.read(u16, vram_base + i * @sizeOf(u16));
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], COLOUR_LUT[bgr555 & 0x7FFF]);
                }
            },
            0x4 => {
                const sel = self.dispcnt.frame_select.read();
                const vram_base = width * @as(usize, scanline) + if (sel) 0xA000 else @as(usize, 0);
                const fb_base = framebuf_pitch * @as(usize, scanline);

                // Render Current Scanline
                for (self.vram.buf[vram_base .. vram_base + width]) |byte, i| {
                    const bgr555 = self.palette.read(u16, @as(u16, byte) * @sizeOf(u16));
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], COLOUR_LUT[bgr555 & 0x7FFF]);
                }
            },
            0x5 => {
                const m5_width = 160;
                const m5_height = 128;

                const sel = self.dispcnt.frame_select.read();
                const vram_base = m5_width * @sizeOf(u16) * @as(usize, scanline) + if (sel) 0xA000 else @as(usize, 0);
                const fb_base = framebuf_pitch * @as(usize, scanline);

                var i: usize = 0;
                while (i < width) : (i += 1) {
                    // If we're outside of the bounds of mode 5, draw the background colour
                    const bgr555 =
                        if (scanline < m5_height and i < m5_width) self.vram.read(u16, vram_base + i * @sizeOf(u16)) else self.palette.getBackdrop();

                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], COLOUR_LUT[bgr555 & 0x7FFF]);
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

    pub fn handleHDrawEnd(self: *Self, cpu: *Arm7tdmi, late: u64) void {
        // Transitioning to a Hblank
        if (self.dispstat.hblank_irq.read()) {
            cpu.bus.io.irq.hblank.set();
            cpu.handleInterrupt();
        }

        // See if HBlank DMA is present and not enabled
        pollBlankingDma(&cpu.bus, .HBlank);

        self.dispstat.hblank.set();
        self.sched.push(.HBlank, 68 * 4 -| late);
    }

    pub fn handleHBlankEnd(self: *Self, cpu: *Arm7tdmi, late: u64) void {
        // The End of a Hblank (During Draw or Vblank)
        const old_scanline = self.vcount.scanline.read();
        const scanline = (old_scanline + 1) % 228;

        self.vcount.scanline.write(scanline);
        self.dispstat.hblank.unset();

        // Perform Vc == VcT check
        const coincidence = scanline == self.dispstat.vcount_trigger.read();
        self.dispstat.coincidence.write(coincidence);

        if (coincidence and self.dispstat.vcount_irq.read()) {
            cpu.bus.io.irq.coincidence.set();
            cpu.handleInterrupt();
        }

        if (scanline < 160) {
            // Transitioning to another Draw
            self.sched.push(.Draw, 240 * 4 -| late);
        } else {
            // Transitioning to a Vblank
            if (scanline == 160) {
                self.framebuf.swap(); // Swap FrameBuffers

                self.dispstat.vblank.set();

                if (self.dispstat.vblank_irq.read()) {
                    cpu.bus.io.irq.vblank.set();
                    cpu.handleInterrupt();
                }

                // See if Vblank DMA is present and not enabled
                pollBlankingDma(&cpu.bus, .VBlank);
            }

            if (scanline == 227) self.dispstat.vblank.unset();
            self.sched.push(.VBlank, 240 * 4 -| late);
        }
    }
};

const Palette = struct {
    const palram_size = 0x400;
    const Self = @This();

    buf: []u8,
    alloc: Allocator,

    fn init(alloc: Allocator) !Self {
        const buf = try alloc.alloc(u8, palram_size);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .alloc = alloc,
        };
    }

    fn deinit(self: Self) void {
        self.alloc.free(self.buf);
    }

    pub fn read(self: *const Self, comptime T: type, address: usize) T {
        const addr = address & 0x3FF;

        return switch (T) {
            u32, u16, u8 => std.mem.readIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)]),
            else => @compileError("PALRAM: Unsupported read width"),
        };
    }

    pub fn write(self: *Self, comptime T: type, address: usize, value: T) void {
        const addr = address & 0x3FF;

        switch (T) {
            u32, u16 => std.mem.writeIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)], value),
            u8 => {
                const halfword: u16 = @as(u16, value) * 0x0101;
                // FIXME: I don't think my comment here makes sense?
                const weird_addr = addr & ~@as(u32, 1); // *was* 8-bit read so address won't be aligned

                std.mem.writeIntSliceLittle(u16, self.buf[weird_addr..(weird_addr + @sizeOf(u16))], halfword);
            },
            else => @compileError("PALRAM: Unsupported write width"),
        }
    }

    fn getBackdrop(self: *const Self) u16 {
        return self.read(u16, 0);
    }
};

const Vram = struct {
    const vram_size = 0x18000;
    const Self = @This();

    buf: []u8,
    alloc: Allocator,

    fn init(alloc: Allocator) !Self {
        const buf = try alloc.alloc(u8, vram_size);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .alloc = alloc,
        };
    }

    fn deinit(self: Self) void {
        self.alloc.free(self.buf);
    }

    pub fn read(self: *const Self, comptime T: type, address: usize) T {
        const addr = Self.mirror(address);

        return switch (T) {
            u32, u16, u8 => std.mem.readIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)]),
            else => @compileError("VRAM: Unsupported read width"),
        };
    }

    pub fn write(self: *Self, comptime T: type, dispcnt: io.DisplayControl, address: usize, value: T) void {
        const mode: u3 = dispcnt.bg_mode.read();
        const addr = Self.mirror(address);

        switch (T) {
            u32, u16 => std.mem.writeIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)], value),
            u8 => {
                // Ignore if write is in OBJ
                switch (mode) {
                    0, 1, 2 => if (0x0601_0000 <= address and address < 0x0601_8000) return,
                    else => if (0x0601_4000 <= address and address < 0x0601_8000) return,
                }

                const halfword: u16 = @as(u16, value) * 0x0101;
                const weird_addr = addr & ~@as(u32, 1);

                std.mem.writeIntSliceLittle(u16, self.buf[weird_addr..(weird_addr + @sizeOf(u16))], halfword);
            },
            else => @compileError("VRAM: Unsupported write width"),
        }
    }

    fn mirror(address: usize) usize {
        // Mirrored in steps of 128K (64K + 32K + 32K) (abcc)
        const addr = address & 0x1FFFF;

        // If the address is within 96K we don't do anything,
        // otherwise we want to mirror the last 32K (addresses between 64K and 96K)
        return if (addr < vram_size) addr else 0x10000 + (addr & 0x7FFF);
    }
};

const Oam = struct {
    const oam_size = 0x400;
    const Self = @This();

    buf: []u8,
    alloc: Allocator,

    fn init(alloc: Allocator) !Self {
        const buf = try alloc.alloc(u8, oam_size);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .alloc = alloc,
        };
    }

    fn deinit(self: Self) void {
        self.alloc.free(self.buf);
    }

    pub fn read(self: *const Self, comptime T: type, address: usize) T {
        const addr = address & 0x3FF;

        return switch (T) {
            u32, u16, u8 => std.mem.readIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)]),
            else => @compileError("OAM: Unsupported read width"),
        };
    }

    pub fn write(self: *Self, comptime T: type, address: usize, value: T) void {
        const addr = address & 0x3FF;

        switch (T) {
            u32, u16 => std.mem.writeIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)], value),
            u8 => return, // 8-bit writes are explicitly ignored
            else => @compileError("OAM: Unsupported write width"),
        }
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

const AffineBackground = struct {
    const Self = @This();

    bg: [2]AffineBackgroundRegisters,

    fn init() Self {
        return .{
            .bg = [_]AffineBackgroundRegisters{AffineBackgroundRegisters.init()} ** 2,
        };
    }
};

const AffineBackgroundRegisters = struct {
    const Self = @This();

    x: io.BackgroundRefPoint,
    y: io.BackgroundRefPoint,

    pa: io.BackgroundRotScaleParam,
    pb: io.BackgroundRotScaleParam,
    pc: io.BackgroundRotScaleParam,
    pd: io.BackgroundRotScaleParam,

    fn init() Self {
        return .{
            .x = .{ .raw = 0 },
            .y = .{ .raw = 0 },
            .pa = .{ .raw = 0 },
            .pb = .{ .raw = 0 },
            .pc = .{ .raw = 0 },
            .pd = .{ .raw = 0 },
        };
    }

    pub fn writePaPb(self: *Self, value: u32) void {
        self.pa.raw = @truncate(u16, value);
        self.pb.raw = @truncate(u16, value >> 16);
    }

    pub fn writePcPd(self: *Self, value: u32) void {
        self.pc.raw = @truncate(u16, value);
        self.pd.raw = @truncate(u16, value >> 16);
    }
};

const ScreenEntry = extern union {
    tile_id: Bitfield(u16, 0, 10),
    h_flip: Bit(u16, 10),
    v_flip: Bit(u16, 11),
    pal_bank: Bitfield(u16, 12, 4),
    raw: u16,
};

const Sprite = struct {
    const Self = @This();

    attr0: Attr0,
    attr1: Attr1,
    attr2: Attr2,

    width: u8,
    height: u8,

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

    fn x(self: *const Self) u9 {
        return self.attr1.x.read();
    }

    fn y(self: *const Self) u8 {
        return self.attr0.y.read();
    }

    fn is_8bpp(self: *const Self) bool {
        return self.attr0.is_8bpp.read();
    }

    fn shape(self: *const Self) u2 {
        return self.attr0.shape.read();
    }

    fn size(self: *const Self) u2 {
        return self.attr1.size.read();
    }

    fn tile_id(self: *const Self) u10 {
        return self.attr2.tile_id.read();
    }

    fn pal_bank(self: *const Self) u4 {
        return self.attr2.pal_bank.read();
    }

    fn h_flip(self: *const Self) bool {
        return self.attr1.h_flip.read();
    }

    fn v_flip(self: *const Self) bool {
        return self.attr1.v_flip.read();
    }

    fn priority(self: *const Self) u2 {
        return self.attr2.rel_prio.read();
    }
};

const AffineSprite = struct {
    const Self = @This();

    attr0: AffineAttr0,
    attr1: AffineAttr1,
    attr2: Attr2,

    width: u8,
    height: u8,

    fn init(attr0: AffineAttr0, attr1: AffineAttr1, attr2: Attr2) Self {
        const d = spriteDimensions(attr0.shape.read(), attr1.size.read());

        return .{
            .attr0 = attr0,
            .attr1 = attr1,
            .attr2 = attr2,
            .width = d[0],
            .height = d[1],
        };
    }
};

const Attr0 = extern union {
    y: Bitfield(u16, 0, 8),
    is_affine: Bit(u16, 8), // This SBZ
    disabled: Bit(u16, 9),
    mode: Bitfield(u16, 10, 2),
    mosaic: Bit(u16, 12),
    is_8bpp: Bit(u16, 13),
    shape: Bitfield(u16, 14, 2),
    raw: u16,
};

const AffineAttr0 = extern union {
    y: Bitfield(u16, 0, 8),
    rot_scaling: Bit(u16, 8), // This SB1
    double_size: Bit(u16, 9),
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

const AffineAttr1 = extern union {
    x: Bitfield(u16, 0, 9),
    aff_sel: Bitfield(u16, 9, 5),
    size: Bitfield(u16, 14, 2),
    raw: u16,
};

const Attr2 = extern union {
    tile_id: Bitfield(u16, 0, 10),
    rel_prio: Bitfield(u16, 10, 2),
    pal_bank: Bitfield(u16, 12, 4),
};

fn spriteDimensions(shape: u2, size: u2) [2]u8 {
    @setRuntimeSafety(false);

    return switch (shape) {
        0b00 => switch (size) {
            // Square
            0b00 => [_]u8{ 8, 8 },
            0b01 => [_]u8{ 16, 16 },
            0b10 => [_]u8{ 32, 32 },
            0b11 => [_]u8{ 64, 64 },
        },
        0b01 => switch (size) {
            0b00 => [_]u8{ 16, 8 },
            0b01 => [_]u8{ 32, 8 },
            0b10 => [_]u8{ 32, 16 },
            0b11 => [_]u8{ 64, 32 },
        },
        0b10 => switch (size) {
            0b00 => [_]u8{ 8, 16 },
            0b01 => [_]u8{ 8, 32 },
            0b10 => [_]u8{ 16, 32 },
            0b11 => [_]u8{ 32, 64 },
        },
        else => std.debug.panic("{} is an invalid sprite shape", .{shape}),
    };
}

fn toRgba8888(bgr555: u16) u32 {
    const b = @as(u32, bgr555 >> 10 & 0x1F);
    const g = @as(u32, bgr555 >> 5 & 0x1F);
    const r = @as(u32, bgr555 & 0x1F);

    return (r << 3 | r >> 2) << 24 | (g << 3 | g >> 2) << 16 | (b << 3 | b >> 2) << 8 | 0xFF;
}

fn genColourLut() [0x8000]u32 {
    return comptime {
        @setEvalBranchQuota(0x10001);

        var lut: [0x8000]u32 = undefined;
        for (lut) |*px, i| px.* = toRgba8888(i);
        return lut;
    };
}

// FIXME: The implementation is incorrect and using it in the LUT crashes the compiler (OOM)
/// Implementation courtesy of byuu and Talarubi at https://near.sh/articles/video/color-emulation
fn toRgba8888Talarubi(bgr555: u16) u32 {
    @setRuntimeSafety(false);

    const lcd_gamma: f64 = 4;
    const out_gamma: f64 = 2.2;

    const b = @as(u32, bgr555 >> 10 & 0x1F);
    const g = @as(u32, bgr555 >> 5 & 0x1F);
    const r = @as(u32, bgr555 & 0x1F);

    const lb = std.math.pow(f64, @intToFloat(f64, b << 3 | b >> 2) / 31, lcd_gamma);
    const lg = std.math.pow(f64, @intToFloat(f64, g << 3 | g >> 2) / 31, lcd_gamma);
    const lr = std.math.pow(f64, @intToFloat(f64, r << 3 | r >> 2) / 31, lcd_gamma);

    const out_b = std.math.pow(f64, (220 * lb + 10 * lg + 50 * lr) / 255, 1 / out_gamma);
    const out_g = std.math.pow(f64, (30 * lb + 230 * lg + 10 * lr) / 255, 1 / out_gamma);
    const out_r = std.math.pow(f64, (0 * lb + 50 * lg + 255 * lr) / 255, 1 / out_gamma);

    return @floatToInt(u32, out_r) << 24 | @floatToInt(u32, out_g) << 16 | @floatToInt(u32, out_b) << 8 | 0xFF;
}

// Double Buffering Implementation
const FrameBuffer = struct {
    const Self = @This();

    buf: [2][]u8,
    original: []u8,
    current: u1,

    // TODO: Rename
    const Device = enum {
        Emulator,
        Renderer,
    };

    pub fn init(bufs: []u8) Self {
        std.debug.assert(bufs.len == framebuf_pitch * height * 2);

        const front = bufs[0 .. framebuf_pitch * height];
        const back = bufs[framebuf_pitch * height ..];

        return .{
            .buf = [2][]u8{ front, back },
            .original = bufs,
            .current = 0,
        };
    }

    fn deinit(self: Self, alloc: Allocator) void {
        alloc.free(self.original);
    }

    pub fn swap(self: *Self) void {
        self.current = ~self.current;
    }

    pub fn get(self: *Self, comptime dev: Device) []u8 {
        return self.buf[if (dev == .Emulator) self.current else ~self.current];
    }
};
