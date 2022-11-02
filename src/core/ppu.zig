const std = @import("std");
const io = @import("bus/io.zig");
const util = @import("../util.zig");

const Scheduler = @import("scheduler.zig").Scheduler;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.PPU);

const getHalf = util.getHalf;
const setHalf = util.setHalf;
const setQuart = util.setQuart;
const pollDmaOnBlank = @import("bus/dma.zig").pollDmaOnBlank;

pub const width = 240;
pub const height = 160;
pub const framebuf_pitch = width * @sizeOf(u32);

pub fn read(comptime T: type, ppu: *const Ppu, addr: u32) ?T {
    const byte_addr = @truncate(u8, addr);

    return switch (T) {
        u32 => switch (byte_addr) {
            0x00 => ppu.dispcnt.raw, // Green Swap is in high half-word
            0x04 => @as(T, ppu.vcount.raw) << 16 | ppu.dispstat.raw,
            0x08 => @as(T, ppu.bg[1].bg1Cnt()) << 16 | ppu.bg[0].bg0Cnt(),
            0x0C => @as(T, ppu.bg[3].cnt.raw) << 16 | ppu.bg[2].cnt.raw,
            0x10, 0x14, 0x18, 0x1C => null, // BGXHOFS/VOFS
            0x20, 0x24, 0x28, 0x2C => null, // BG2 Rot/Scaling
            0x30, 0x34, 0x38, 0x3C => null, // BG3 Rot/Scaling
            0x40, 0x44 => null, // WINXH/V Registers
            0x48 => @as(T, ppu.win.getOut()) << 16 | ppu.win.getIn(),
            0x4C => null, // MOSAIC, undefined in high byte
            0x50 => @as(T, ppu.bld.getAlpha()) << 16 | ppu.bld.getCnt(),
            0x54 => null, // BLDY, undefined in high half-wrd
            else => util.io.read.err(T, log, "unaligned {} read from 0x{X:0>8}", .{ T, addr }),
        },
        u16 => switch (byte_addr) {
            0x00 => ppu.dispcnt.raw,
            0x02 => null, // Green Swap
            0x04 => ppu.dispstat.raw,
            0x06 => ppu.vcount.raw,
            0x08 => ppu.bg[0].bg0Cnt(),
            0x0A => ppu.bg[1].bg1Cnt(),
            0x0C => ppu.bg[2].cnt.raw,
            0x0E => ppu.bg[3].cnt.raw,
            0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x1C, 0x1E => null, // BGXHOFS/VOFS
            0x20, 0x22, 0x24, 0x26, 0x28, 0x2A, 0x2C, 0x2E => null, // BG2 Rot/Scaling
            0x30, 0x32, 0x34, 0x36, 0x38, 0x3A, 0x3C, 0x3E => null, // BG3 Rot/Scaling
            0x40, 0x42, 0x44, 0x46 => null, // WINXH/V Registers
            0x48 => ppu.win.getIn(),
            0x4A => ppu.win.getOut(),
            0x4C => null, // MOSAIC
            0x4E => null,
            0x50 => ppu.bld.getCnt(),
            0x52 => ppu.bld.getAlpha(),
            0x54 => null, // BLDY
            else => util.io.read.err(T, log, "unaligned {} read from 0x{X:0>8}", .{ T, addr }),
        },
        u8 => switch (byte_addr) {
            0x00, 0x01 => @truncate(T, ppu.dispcnt.raw >> getHalf(byte_addr)),
            0x02, 0x03 => null,
            0x04, 0x05 => @truncate(T, ppu.dispstat.raw >> getHalf(byte_addr)),
            0x06, 0x07 => @truncate(T, ppu.vcount.raw >> getHalf(byte_addr)),
            0x08, 0x09 => @truncate(T, ppu.bg[0].bg0Cnt() >> getHalf(byte_addr)),
            0x0A, 0x0B => @truncate(T, ppu.bg[1].bg1Cnt() >> getHalf(byte_addr)),
            0x0C, 0x0D => @truncate(T, ppu.bg[2].cnt.raw >> getHalf(byte_addr)),
            0x0E, 0x0F => @truncate(T, ppu.bg[3].cnt.raw >> getHalf(byte_addr)),
            0x10...0x1F => null, // BGXHOFS/VOFS
            0x20...0x2F => null, // BG2 Rot/Scaling
            0x30...0x3F => null, // BG3 Rot/Scaling
            0x40...0x47 => null, // WINXH/V Registers
            0x48, 0x49 => @truncate(T, ppu.win.getIn() >> getHalf(byte_addr)),
            0x4A, 0x4B => @truncate(T, ppu.win.getOut() >> getHalf(byte_addr)),
            0x4C, 0x4D => null, // MOSAIC
            0x4E, 0x4F => null,
            0x50, 0x51 => @truncate(T, ppu.bld.getCnt() >> getHalf(byte_addr)),
            0x52, 0x53 => @truncate(T, ppu.bld.getAlpha() >> getHalf(byte_addr)),
            0x54, 0x55 => null, // BLDY
            else => util.io.read.err(T, log, "unexpected {} read from 0x{X:0>8}", .{ T, addr }),
        },
        else => @compileError("PPU: Unsupported read width"),
    };
}

pub fn write(comptime T: type, ppu: *Ppu, addr: u32, value: T) void {
    const byte_addr = @truncate(u8, addr); // prefixed with 0x0400_00

    switch (T) {
        u32 => switch (byte_addr) {
            0x00 => ppu.dispcnt.raw = @truncate(u16, value),
            0x04 => {
                ppu.dispstat.set(@truncate(u16, value));
                ppu.vcount.raw = @truncate(u16, value >> 16);
            },
            0x08 => ppu.setAdjCnts(0, value),
            0x0C => ppu.setAdjCnts(2, value),

            0x10 => ppu.setBgOffsets(0, value),
            0x14 => ppu.setBgOffsets(1, value),
            0x18 => ppu.setBgOffsets(2, value),
            0x1C => ppu.setBgOffsets(3, value),

            0x20 => ppu.aff_bg[0].writePaPb(value),
            0x24 => ppu.aff_bg[0].writePcPd(value),
            0x28 => ppu.aff_bg[0].setX(ppu.dispstat.vblank.read(), value),
            0x2C => ppu.aff_bg[0].setY(ppu.dispstat.vblank.read(), value),

            0x30 => ppu.aff_bg[1].writePaPb(value),
            0x34 => ppu.aff_bg[1].writePcPd(value),
            0x38 => ppu.aff_bg[1].setX(ppu.dispstat.vblank.read(), value),
            0x3C => ppu.aff_bg[1].setY(ppu.dispstat.vblank.read(), value),

            0x40 => ppu.win.setH(value),
            0x44 => ppu.win.setV(value),
            0x48 => ppu.win.setIo(value),
            0x4C => log.debug("Wrote 0x{X:0>8} to MOSAIC", .{value}),

            0x50 => {
                ppu.bld.cnt.raw = @truncate(u16, value);
                ppu.bld.alpha.raw = @truncate(u16, value >> 16);
            },
            0x54 => ppu.bld.y.raw = @truncate(u16, value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>8}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u16 => switch (byte_addr) {
            0x00 => ppu.dispcnt.raw = value,
            0x02 => {}, // Green Swap
            0x04 => ppu.dispstat.set(value),
            0x06 => {}, // VCOUNT

            0x08 => ppu.bg[0].cnt.raw = value,
            0x0A => ppu.bg[1].cnt.raw = value,
            0x0C => ppu.bg[2].cnt.raw = value,
            0x0E => ppu.bg[3].cnt.raw = value,

            0x10 => ppu.bg[0].hofs.raw = value, // TODO: Don't write out every HOFS / VOFS?
            0x12 => ppu.bg[0].vofs.raw = value,
            0x14 => ppu.bg[1].hofs.raw = value,
            0x16 => ppu.bg[1].vofs.raw = value,
            0x18 => ppu.bg[2].hofs.raw = value,
            0x1A => ppu.bg[2].vofs.raw = value,
            0x1C => ppu.bg[3].hofs.raw = value,
            0x1E => ppu.bg[3].vofs.raw = value,

            0x20 => ppu.aff_bg[0].pa = @bitCast(i16, value),
            0x22 => ppu.aff_bg[0].pb = @bitCast(i16, value),
            0x24 => ppu.aff_bg[0].pc = @bitCast(i16, value),
            0x26 => ppu.aff_bg[0].pd = @bitCast(i16, value),
            0x28, 0x2A => ppu.aff_bg[0].x = @bitCast(i32, setHalf(u32, @bitCast(u32, ppu.aff_bg[0].x), byte_addr, value)),
            0x2C, 0x2E => ppu.aff_bg[0].y = @bitCast(i32, setHalf(u32, @bitCast(u32, ppu.aff_bg[0].y), byte_addr, value)),

            0x30 => ppu.aff_bg[1].pa = @bitCast(i16, value),
            0x32 => ppu.aff_bg[1].pb = @bitCast(i16, value),
            0x34 => ppu.aff_bg[1].pc = @bitCast(i16, value),
            0x36 => ppu.aff_bg[1].pd = @bitCast(i16, value),
            0x38, 0x3A => ppu.aff_bg[1].x = @bitCast(i32, setHalf(u32, @bitCast(u32, ppu.aff_bg[1].x), byte_addr, value)),
            0x3C, 0x3E => ppu.aff_bg[1].y = @bitCast(i32, setHalf(u32, @bitCast(u32, ppu.aff_bg[1].y), byte_addr, value)),

            0x40 => ppu.win.h[0].raw = value,
            0x42 => ppu.win.h[1].raw = value,
            0x44 => ppu.win.v[0].raw = value,
            0x46 => ppu.win.v[1].raw = value,
            0x48 => ppu.win.in.raw = value,
            0x4A => ppu.win.out.raw = value,
            0x4C => log.debug("Wrote 0x{X:0>4} to MOSAIC", .{value}),
            0x4E => {},

            0x50 => ppu.bld.cnt.raw = value,
            0x52 => ppu.bld.alpha.raw = value,
            0x54 => ppu.bld.y.raw = value,
            else => util.io.write.undef(log, "Tried to write 0x{X:0>4}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u8 => switch (byte_addr) {
            0x00, 0x01 => ppu.dispcnt.raw = setHalf(u16, ppu.dispcnt.raw, byte_addr, value),
            0x02, 0x03 => {}, // Green Swap
            0x04, 0x05 => ppu.dispstat.set(setHalf(u16, ppu.dispstat.raw, byte_addr, value)),
            0x06, 0x07 => {}, // VCOUNT

            // BGXCNT
            0x08, 0x09 => ppu.bg[0].cnt.raw = setHalf(u16, ppu.bg[0].cnt.raw, byte_addr, value),
            0x0A, 0x0B => ppu.bg[1].cnt.raw = setHalf(u16, ppu.bg[1].cnt.raw, byte_addr, value),
            0x0C, 0x0D => ppu.bg[2].cnt.raw = setHalf(u16, ppu.bg[2].cnt.raw, byte_addr, value),
            0x0E, 0x0F => ppu.bg[3].cnt.raw = setHalf(u16, ppu.bg[3].cnt.raw, byte_addr, value),

            // BGX HOFS/VOFS
            0x10, 0x11 => ppu.bg[0].hofs.raw = setHalf(u16, ppu.bg[0].hofs.raw, byte_addr, value),
            0x12, 0x13 => ppu.bg[0].vofs.raw = setHalf(u16, ppu.bg[0].vofs.raw, byte_addr, value),
            0x14, 0x15 => ppu.bg[1].hofs.raw = setHalf(u16, ppu.bg[1].hofs.raw, byte_addr, value),
            0x16, 0x17 => ppu.bg[1].vofs.raw = setHalf(u16, ppu.bg[1].vofs.raw, byte_addr, value),
            0x18, 0x19 => ppu.bg[2].hofs.raw = setHalf(u16, ppu.bg[2].hofs.raw, byte_addr, value),
            0x1A, 0x1B => ppu.bg[2].vofs.raw = setHalf(u16, ppu.bg[2].vofs.raw, byte_addr, value),
            0x1C, 0x1D => ppu.bg[3].hofs.raw = setHalf(u16, ppu.bg[3].hofs.raw, byte_addr, value),
            0x1E, 0x1F => ppu.bg[3].vofs.raw = setHalf(u16, ppu.bg[3].vofs.raw, byte_addr, value),

            // BG2 Rot/Scaling
            0x20, 0x21 => ppu.aff_bg[0].pa = @bitCast(i16, setHalf(u16, @bitCast(u16, ppu.aff_bg[0].pa), byte_addr, value)),
            0x22, 0x23 => ppu.aff_bg[0].pb = @bitCast(i16, setHalf(u16, @bitCast(u16, ppu.aff_bg[0].pb), byte_addr, value)),
            0x24, 0x25 => ppu.aff_bg[0].pc = @bitCast(i16, setHalf(u16, @bitCast(u16, ppu.aff_bg[0].pc), byte_addr, value)),
            0x26, 0x27 => ppu.aff_bg[0].pd = @bitCast(i16, setHalf(u16, @bitCast(u16, ppu.aff_bg[0].pd), byte_addr, value)),
            0x28, 0x29, 0x2A, 0x2B => ppu.aff_bg[0].x = @bitCast(i32, setQuart(@bitCast(u32, ppu.aff_bg[0].x), byte_addr, value)),
            0x2C, 0x2D, 0x2E, 0x2F => ppu.aff_bg[0].y = @bitCast(i32, setQuart(@bitCast(u32, ppu.aff_bg[0].y), byte_addr, value)),

            // BG3 Rot/Scaling
            0x30, 0x31 => ppu.aff_bg[1].pa = @bitCast(i16, setHalf(u16, @bitCast(u16, ppu.aff_bg[1].pa), byte_addr, value)),
            0x32, 0x33 => ppu.aff_bg[1].pb = @bitCast(i16, setHalf(u16, @bitCast(u16, ppu.aff_bg[1].pb), byte_addr, value)),
            0x34, 0x35 => ppu.aff_bg[1].pc = @bitCast(i16, setHalf(u16, @bitCast(u16, ppu.aff_bg[1].pc), byte_addr, value)),
            0x36, 0x37 => ppu.aff_bg[1].pd = @bitCast(i16, setHalf(u16, @bitCast(u16, ppu.aff_bg[1].pd), byte_addr, value)),
            0x38, 0x39, 0x3A, 0x3B => ppu.aff_bg[1].x = @bitCast(i32, setQuart(@bitCast(u32, ppu.aff_bg[1].x), byte_addr, value)),
            0x3C, 0x3D, 0x3E, 0x3F => ppu.aff_bg[1].y = @bitCast(i32, setQuart(@bitCast(u32, ppu.aff_bg[1].y), byte_addr, value)),

            // Window
            0x40, 0x41 => ppu.win.h[0].raw = setHalf(u16, ppu.win.h[0].raw, byte_addr, value),
            0x42, 0x43 => ppu.win.h[1].raw = setHalf(u16, ppu.win.h[1].raw, byte_addr, value),
            0x44, 0x45 => ppu.win.v[0].raw = setHalf(u16, ppu.win.v[0].raw, byte_addr, value),
            0x46, 0x47 => ppu.win.v[1].raw = setHalf(u16, ppu.win.v[1].raw, byte_addr, value),
            0x48, 0x49 => ppu.win.in.raw = setHalf(u16, ppu.win.in.raw, byte_addr, value),
            0x4A, 0x4B => ppu.win.out.raw = setHalf(u16, ppu.win.out.raw, byte_addr, value),
            0x4C, 0x4D => log.debug("Wrote 0x{X:0>2} to MOSAIC", .{value}),
            0x4E, 0x4F => {},

            // Blending
            0x50, 0x51 => ppu.bld.cnt.raw = setHalf(u16, ppu.bld.cnt.raw, byte_addr, value),
            0x52, 0x53 => ppu.bld.alpha.raw = setHalf(u16, ppu.bld.alpha.raw, byte_addr, value),
            0x54, 0x55 => ppu.bld.y.raw = setHalf(u16, ppu.bld.y.raw, byte_addr, value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>2}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        else => @compileError("PPU: Unsupported write width"),
    }
}

pub const Ppu = struct {
    const Self = @This();

    // Registers

    win: Window,
    bg: [4]Background,
    aff_bg: [2]AffineBackground,

    dispcnt: io.DisplayControl,
    dispstat: io.DisplayStatus,
    vcount: io.VCount,

    bld: Blend,

    vram: Vram,
    palette: Palette,
    oam: Oam,
    sched: *Scheduler,
    framebuf: FrameBuffer,
    allocator: Allocator,

    scanline_sprites: *[128]?Sprite,
    scanline: Scanline,

    pub fn init(allocator: Allocator, sched: *Scheduler) !Self {
        // Queue first Hblank
        sched.push(.Draw, 240 * 4);

        const sprites = try allocator.create([128]?Sprite);
        sprites.* = [_]?Sprite{null} ** 128;

        return Self{
            .vram = try Vram.init(allocator),
            .palette = try Palette.init(allocator),
            .oam = try Oam.init(allocator),
            .sched = sched,
            .framebuf = try FrameBuffer.init(allocator),
            .allocator = allocator,

            // Registers
            .win = Window.init(),
            .bg = [_]Background{Background.init()} ** 4,
            .aff_bg = [_]AffineBackground{AffineBackground.init()} ** 2,
            .bld = Blend.create(),
            .dispcnt = .{ .raw = 0x0000 },
            .dispstat = .{ .raw = 0x0000 },
            .vcount = .{ .raw = 0x0000 },

            .scanline = try Scanline.init(allocator),
            .scanline_sprites = sprites,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self.scanline_sprites);
        self.framebuf.deinit();
        self.scanline.deinit();
        self.vram.deinit();
        self.palette.deinit();
        self.oam.deinit();
        self.* = undefined;
    }

    pub fn setBgOffsets(self: *Self, comptime n: u2, word: u32) void {
        self.bg[n].hofs.raw = @truncate(u16, word);
        self.bg[n].vofs.raw = @truncate(u16, word >> 16);
    }

    pub fn setAdjCnts(self: *Self, comptime n: u2, word: u32) void {
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
            if (attr0.is_affine.read() or !attr0.disabled.read()) {
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

    fn drawSprites(self: *Self, layer: u2) void {
        // Loop over every fetched sprite
        for (self.scanline_sprites) |maybe_sprite| {
            if (maybe_sprite) |sprite| {
                // Skip this sprite if it isn't on the current priority
                if (sprite.priority() != layer) continue;
                if (sprite.attr0.is_affine.read()) self.drawAffineSprite(AffineSprite.from(sprite)) else self.drawSprite(sprite);
            } else break;
        }
    }

    fn drawAffineSprite(self: *Self, sprite: AffineSprite) void {
        const iy = @bitCast(i8, self.vcount.scanline.read());

        const is_8bpp = sprite.is8bpp();
        const tile_id: u32 = sprite.tileId();
        const obj_mapping = self.dispcnt.obj_mapping.read();
        const tile_row_offset: u32 = if (is_8bpp) 8 else 4;
        const tile_len: u32 = if (is_8bpp) 0x40 else 0x20;

        const char_base = 0x4000 * 4;

        var i: u9 = 0;
        while (i < sprite.width) : (i += 1) {
            const x = (sprite.x() +% i) % width;
            const ix = @bitCast(i9, x);

            if (!shouldDrawSprite(self.bld.cnt, &self.scanline, x)) continue;

            const sprite_start = sprite.x();
            const isprite_start = @bitCast(i9, sprite_start);
            const sprite_end = sprite_start +% sprite.width;
            const isprite_end = @bitCast(i9, sprite_end);

            const condition = (sprite_start <= x and x < sprite_end) or (isprite_start <= ix and ix < isprite_end);
            if (!condition) continue;

            // Sprite is within bounds and therefore should be rendered
            // std.math.absInt is branchless
            const tile_x = @bitCast(u9, std.math.absInt(ix - @bitCast(i9, sprite.x())) catch unreachable);
            const tile_y = @bitCast(u8, std.math.absInt(iy -% @bitCast(i8, sprite.y())) catch unreachable);

            const row = @truncate(u3, tile_y);
            const col = @truncate(u3, tile_x);

            // TODO: Finish that 2D Sprites Test ROM
            const tile_base = char_base + (tile_id * 0x20) + (row * tile_row_offset) + if (is_8bpp) col else col >> 1;
            const mapping_offset = if (obj_mapping) sprite.width >> 3 else if (is_8bpp) @as(u32, 0x10) else 0x20;
            const tile_offset = (tile_x >> 3) * tile_len + (tile_y >> 3) * tile_len * mapping_offset;

            const tile = self.vram.buf[tile_base + tile_offset];
            const pal_id: u16 = if (!is_8bpp) get4bppTilePalette(sprite.palBank(), col, tile) else tile;

            // Sprite Palette starts at 0x0500_0200
            if (pal_id != 0) {
                const bgr555 = self.palette.read(u16, 0x200 + pal_id * 2);
                copyToSpriteBuffer(self.bld.cnt, &self.scanline, x, bgr555);
            }
        }
    }

    fn drawSprite(self: *Self, sprite: Sprite) void {
        const iy = @bitCast(i8, self.vcount.scanline.read());

        const is_8bpp = sprite.is8bpp();
        const tile_id: u32 = sprite.tileId();
        const obj_mapping = self.dispcnt.obj_mapping.read();
        const tile_row_offset: u32 = if (is_8bpp) 8 else 4;
        const tile_len: u32 = if (is_8bpp) 0x40 else 0x20;

        const char_base = 0x4000 * 4;

        var i: u9 = 0;
        while (i < sprite.width) : (i += 1) {
            const x = (sprite.x() +% i) % width;
            const ix = @bitCast(i9, x);

            if (!shouldDrawSprite(self.bld.cnt, &self.scanline, x)) continue;

            const sprite_start = sprite.x();
            const isprite_start = @bitCast(i9, sprite_start);
            const sprite_end = sprite_start +% sprite.width;
            const isprite_end = @bitCast(i9, sprite_end);

            const condition = (sprite_start <= x and x < sprite_end) or (isprite_start <= ix and ix < isprite_end);
            if (!condition) continue;

            // Sprite is within bounds and therefore should be rendered
            // std.math.absInt is branchless
            const x_diff = @bitCast(u9, std.math.absInt(ix - @bitCast(i9, sprite.x())) catch unreachable);
            const y_diff = @bitCast(u8, std.math.absInt(iy -% @bitCast(i8, sprite.y())) catch unreachable);

            // Note that we flip the tile_pos not the (tile_pos % 8) like we do for
            // Background Tiles. By doing this we mirror the entire sprite instead of
            // just a specific tile (see how sprite.width and sprite.height are involved)
            const tile_y = y_diff ^ if (sprite.vFlip()) (sprite.height - 1) else 0;
            const tile_x = x_diff ^ if (sprite.hFlip()) (sprite.width - 1) else 0;

            const row = @truncate(u3, tile_y);
            const col = @truncate(u3, tile_x);

            // TODO: Finish that 2D Sprites Test ROM
            const tile_base = char_base + (tile_id * 0x20) + (row * tile_row_offset) + if (is_8bpp) col else col >> 1;
            const mapping_offset = if (obj_mapping) sprite.width >> 3 else if (is_8bpp) @as(u32, 0x10) else 0x20;
            const tile_offset = (tile_x >> 3) * tile_len + (tile_y >> 3) * tile_len * mapping_offset;

            const tile = self.vram.buf[tile_base + tile_offset];
            const pal_id: u16 = if (!is_8bpp) get4bppTilePalette(sprite.palBank(), col, tile) else tile;

            // Sprite Palette starts at 0x0500_0200
            if (pal_id != 0) {
                const bgr555 = self.palette.read(u16, 0x200 + pal_id * 2);
                copyToSpriteBuffer(self.bld.cnt, &self.scanline, x, bgr555);
            }
        }
    }

    fn drawAffineBackground(self: *Self, comptime n: u2) void {
        comptime std.debug.assert(n == 2 or n == 3); // Only BG2 and BG3 can be affine

        const char_base = @as(u32, 0x4000) * self.bg[n].cnt.char_base.read();
        const screen_base = @as(u32, 0x800) * self.bg[n].cnt.screen_base.read();
        const size: u2 = self.bg[n].cnt.size.read();
        const tile_width = @as(i32, 0x10) << size;

        const px_width = tile_width << 3;
        const px_height = px_width;

        var aff_x = self.aff_bg[n - 2].x_latch.?;
        var aff_y = self.aff_bg[n - 2].y_latch.?;

        var i: u32 = 0;
        while (i < width) : (i += 1) {
            var ix = aff_x >> 8;
            var iy = aff_y >> 8;

            aff_x += self.aff_bg[n - 2].pa;
            aff_y += self.aff_bg[n - 2].pc;

            if (!shouldDrawBackground(n, self.bld.cnt, &self.scanline, i)) continue;

            if (self.bg[n].cnt.display_overflow.read()) {
                ix = if (ix > px_width) @rem(ix, px_width) else if (ix < 0) px_width + @rem(ix, px_width) else ix;
                iy = if (iy > px_height) @rem(iy, px_height) else if (iy < 0) px_height + @rem(iy, px_height) else iy;
            } else if (ix > px_width or iy > px_height or ix < 0 or iy < 0) continue;

            const x = @bitCast(u32, ix);
            const y = @bitCast(u32, iy);

            const tile_id: u32 = self.vram.read(u8, screen_base + ((y / 8) * @bitCast(u32, tile_width) + (x / 8)));
            const row = y & 7;
            const col = x & 7;

            const tile_addr = char_base + (tile_id * 0x40) + (row * 0x8) + col;
            const pal_id: u16 = self.vram.buf[tile_addr];

            if (pal_id != 0) {
                const bgr555 = self.palette.read(u16, pal_id * 2);
                copyToBackgroundBuffer(n, self.bld.cnt, &self.scanline, i, bgr555);
            }
        }

        // Update BGxX and BGxY
        self.aff_bg[n - 2].x_latch.? += self.aff_bg[n - 2].pb; // PB is added to BGxX
        self.aff_bg[n - 2].y_latch.? += self.aff_bg[n - 2].pd; // PD is added to BGxY
    }

    fn drawBackround(self: *Self, comptime n: u2) void {
        // A Tile in a charblock is a byte, while a Screen Entry is a halfword

        const char_base = 0x4000 * @as(u32, self.bg[n].cnt.char_base.read());
        const screen_base = 0x800 * @as(u32, self.bg[n].cnt.screen_base.read());
        const is_8bpp: bool = self.bg[n].cnt.colour_mode.read(); // Colour Mode
        const size: u2 = self.bg[n].cnt.size.read(); // Background Size

        // In 4bpp: 1 byte represents two pixels so the length is (8 x 8) / 2
        // In 8bpp: 1 byte represents one pixel so the length is 8 x 8
        const tile_len = if (is_8bpp) @as(u32, 0x40) else 0x20;
        const tile_row_offset = if (is_8bpp) @as(u32, 0x8) else 0x4;

        const vofs: u32 = self.bg[n].vofs.offset.read();
        const hofs: u32 = self.bg[n].hofs.offset.read();

        const y = vofs + self.vcount.scanline.read();

        var i: u32 = 0;
        while (i < width) : (i += 1) {
            if (!shouldDrawBackground(n, self.bld.cnt, &self.scanline, i)) continue;

            const x = hofs + i;

            // Grab the Screen Entry from VRAM
            const entry_addr = screen_base + tilemapOffset(size, x, y);
            const entry = @bitCast(ScreenEntry, self.vram.read(u16, entry_addr));

            // Calculate the Address of the Tile in the designated Charblock
            // We also take this opportunity to flip tiles if necessary
            const tile_id: u32 = entry.tile_id.read();

            // Calculate row and column offsets. Understand that
            // `tile_len`, `tile_row_offset` and `col` are subject to different
            // values depending on whether we are in 4bpp or 8bpp mode.
            const row = @truncate(u3, y) ^ if (entry.v_flip.read()) 7 else @as(u3, 0);
            const col = @truncate(u3, x) ^ if (entry.h_flip.read()) 7 else @as(u3, 0);
            const tile_addr = char_base + (tile_id * tile_len) + (row * tile_row_offset) + if (is_8bpp) col else col >> 1;

            const tile = self.vram.buf[tile_addr];

            // If we're in 8bpp, then the tile value is an index into the palette,
            // If we're in 4bpp, we have to account for a pal bank value in the Screen entry
            // and then we can index the palette
            const pal_id: u16 = if (!is_8bpp) get4bppTilePalette(entry.pal_bank.read(), col, tile) else tile;

            if (pal_id != 0) {
                const bgr555 = self.palette.read(u16, pal_id * 2);
                copyToBackgroundBuffer(n, self.bld.cnt, &self.scanline, i, bgr555);
            }
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
                // If there are any nulls present in self.scanline it means that no background drew a pixel there, so draw backdrop
                for (self.scanline.top()) |maybe_px, i| {
                    const maybe_top = maybe_px;
                    const maybe_btm = self.scanline.btm()[i];

                    const bgr555 = self.getBgr555(maybe_top, maybe_btm);
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], rgba888(bgr555));
                }

                // Reset Current Scanline Pixel Buffer and list of fetched sprites
                // in prep for next scanline
                self.scanline.reset();
                std.mem.set(?Sprite, self.scanline_sprites, null);
            },
            0x1 => {
                const fb_base = framebuf_pitch * @as(usize, scanline);
                if (obj_enable) self.fetchSprites();

                var layer: usize = 0;
                while (layer < 4) : (layer += 1) {
                    self.drawSprites(@truncate(u2, layer));
                    if (layer == self.bg[0].cnt.priority.read() and bg_enable & 1 == 1) self.drawBackround(0);
                    if (layer == self.bg[1].cnt.priority.read() and bg_enable >> 1 & 1 == 1) self.drawBackround(1);
                    if (layer == self.bg[2].cnt.priority.read() and bg_enable >> 2 & 1 == 1) self.drawAffineBackground(2);
                }

                // Copy Drawn Scanline to Frame Buffer
                // If there are any nulls present in self.scanline.top() it means that no background drew a pixel there, so draw backdrop
                for (self.scanline.top()) |maybe_px, i| {
                    const maybe_top = maybe_px;
                    const maybe_btm = self.scanline.btm()[i];

                    const bgr555 = self.getBgr555(maybe_top, maybe_btm);
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], rgba888(bgr555));
                }

                // Reset Current Scanline Pixel Buffer and list of fetched sprites
                // in prep for next scanline
                self.scanline.reset();
                std.mem.set(?Sprite, self.scanline_sprites, null);
            },
            0x2 => {
                const fb_base = framebuf_pitch * @as(usize, scanline);
                if (obj_enable) self.fetchSprites();

                var layer: usize = 0;
                while (layer < 4) : (layer += 1) {
                    self.drawSprites(@truncate(u2, layer));
                    if (layer == self.bg[2].cnt.priority.read() and bg_enable >> 2 & 1 == 1) self.drawAffineBackground(2);
                    if (layer == self.bg[3].cnt.priority.read() and bg_enable >> 3 & 1 == 1) self.drawAffineBackground(3);
                }

                // Copy Drawn Scanline to Frame Buffer
                // If there are any nulls present in self.scanline.top() it means that no background drew a pixel there, so draw backdrop
                for (self.scanline.top()) |maybe_px, i| {
                    const maybe_top = maybe_px;
                    const maybe_btm = self.scanline.btm()[i];

                    const bgr555 = self.getBgr555(maybe_top, maybe_btm);
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], rgba888(bgr555));
                }

                // Reset Current Scanline Pixel Buffer and list of fetched sprites
                // in prep for next scanline
                self.scanline.reset();
                std.mem.set(?Sprite, self.scanline_sprites, null);
            },
            0x3 => {
                const vram_base = width * @sizeOf(u16) * @as(usize, scanline);
                const fb_base = framebuf_pitch * @as(usize, scanline);

                var i: usize = 0;
                while (i < width) : (i += 1) {
                    const bgr555 = self.vram.read(u16, vram_base + i * @sizeOf(u16));
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], rgba888(bgr555));
                }
            },
            0x4 => {
                const sel = self.dispcnt.frame_select.read();
                const vram_base = width * @as(usize, scanline) + if (sel) 0xA000 else @as(usize, 0);
                const fb_base = framebuf_pitch * @as(usize, scanline);

                // Render Current Scanline
                for (self.vram.buf[vram_base .. vram_base + width]) |byte, i| {
                    const bgr555 = self.palette.read(u16, @as(u16, byte) * @sizeOf(u16));
                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], rgba888(bgr555));
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

                    std.mem.writeIntNative(u32, self.framebuf.get(.Emulator)[fb_base + i * @sizeOf(u32) ..][0..@sizeOf(u32)], rgba888(bgr555));
                }
            },
            else => std.debug.panic("[PPU] TODO: Implement BG Mode {}", .{bg_mode}),
        }
    }

    fn getBgr555(self: *Self, maybe_top: ?u16, maybe_btm: ?u16) u16 {
        if (maybe_btm) |btm| {
            return switch (self.bld.cnt.mode.read()) {
                0b00 => if (maybe_top) |top| top else btm,
                0b01 => if (maybe_top) |top| alphaBlend(btm, top, self.bld.alpha) else btm,
                0b10 => blk: {
                    const evy: u16 = self.bld.y.evy.read();

                    const r = btm & 0x1F;
                    const g = (btm >> 5) & 0x1F;
                    const b = (btm >> 10) & 0x1F;

                    const bld_r = r + (((31 - r) * evy) >> 4);
                    const bld_g = g + (((31 - g) * evy) >> 4);
                    const bld_b = b + (((31 - b) * evy) >> 4);

                    break :blk (bld_b << 10) | (bld_g << 5) | bld_r;
                },
                0b11 => blk: {
                    const evy: u16 = self.bld.y.evy.read();

                    const btm_r = btm & 0x1F;
                    const btm_g = (btm >> 5) & 0x1F;
                    const btm_b = (btm >> 10) & 0x1F;

                    const bld_r = btm_r - ((btm_r * evy) >> 4);
                    const bld_g = btm_g - ((btm_g * evy) >> 4);
                    const bld_b = btm_b - ((btm_b * evy) >> 4);

                    break :blk (bld_b << 10) | (bld_g << 5) | bld_r;
                },
            };
        }

        if (maybe_top) |top| return top;
        return self.palette.getBackdrop();
    }

    // TODO: Comment this + get a better understanding
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

    pub fn onHdrawEnd(self: *Self, cpu: *Arm7tdmi, late: u64) void {
        // Transitioning to a Hblank
        if (self.dispstat.hblank_irq.read()) {
            cpu.bus.io.irq.hblank.set();
            cpu.handleInterrupt();
        }

        // See if HBlank DMA is present and not enabled

        if (!self.dispstat.vblank.read())
            pollDmaOnBlank(cpu.bus, .HBlank);

        self.dispstat.hblank.set();
        self.sched.push(.HBlank, 68 * 4 -| late);
    }

    pub fn onHblankEnd(self: *Self, cpu: *Arm7tdmi, late: u64) void {
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

                self.aff_bg[0].latchRefPoints();
                self.aff_bg[1].latchRefPoints();

                // See if Vblank DMA is present and not enabled
                pollDmaOnBlank(cpu.bus, .VBlank);
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
    allocator: Allocator,

    fn init(allocator: Allocator) !Self {
        const buf = try allocator.alloc(u8, palram_size);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.buf);
        self.* = undefined;
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
                const align_addr = addr & ~@as(u32, 1); // Aligned to Halfword boundary
                std.mem.writeIntSliceLittle(u16, self.buf[align_addr..][0..@sizeOf(u16)], @as(u16, value) * 0x101);
            },
            else => @compileError("PALRAM: Unsupported write width"),
        }
    }

    fn getBackdrop(self: *const Self) u16 {
        return self.read(u16, 0);
    }
};

pub const Vram = struct {
    const vram_size = 0x18000;
    const Self = @This();

    buf: []u8,
    allocator: Allocator,

    fn init(allocator: Allocator) !Self {
        const buf = try allocator.alloc(u8, vram_size);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.buf);
        self.* = undefined;
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
        const idx = Self.mirror(address);

        switch (T) {
            u32, u16 => std.mem.writeIntSliceLittle(T, self.buf[idx..][0..@sizeOf(T)], value),
            u8 => {
                // Ignore write if it falls within the boundaries of OBJ VRAM
                switch (mode) {
                    0, 1, 2 => if (0x0001_0000 <= idx) return,
                    else => if (0x0001_4000 <= idx) return,
                }

                const align_idx = idx & ~@as(u32, 1); // Aligned to a halfword boundary
                std.mem.writeIntSliceLittle(u16, self.buf[align_idx..][0..@sizeOf(u16)], @as(u16, value) * 0x101);
            },
            else => @compileError("VRAM: Unsupported write width"),
        }
    }

    pub fn mirror(address: usize) usize {
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
    allocator: Allocator,

    fn init(allocator: Allocator) !Self {
        const buf = try allocator.alloc(u8, oam_size);
        std.mem.set(u8, buf, 0);

        return Self{
            .buf = buf,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.buf);
        self.* = undefined;
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

const Blend = struct {
    const Self = @This();

    cnt: io.BldCnt,
    alpha: io.BldAlpha,
    y: io.BldY,

    pub fn create() Self {
        return .{
            .cnt = .{ .raw = 0x000 },
            .alpha = .{ .raw = 0x000 },
            .y = .{ .raw = 0x000 },
        };
    }

    pub fn getCnt(self: *const Self) u16 {
        return self.cnt.raw & 0x3FFF;
    }

    pub fn getAlpha(self: *const Self) u16 {
        return self.alpha.raw & 0x1F1F;
    }
};

const Window = struct {
    const Self = @This();

    h: [2]io.WinH,
    v: [2]io.WinV,

    out: io.WinOut,
    in: io.WinIn,

    fn init() Self {
        return .{
            .h = [_]io.WinH{.{ .raw = 0 }} ** 2,
            .v = [_]io.WinV{.{ .raw = 0 }} ** 2,

            .out = .{ .raw = 0 },
            .in = .{ .raw = 0 },
        };
    }

    pub fn getIn(self: *const Self) u16 {
        return self.in.raw & 0x3F3F;
    }

    pub fn getOut(self: *const Self) u16 {
        return self.out.raw & 0x3F3F;
    }

    pub fn setH(self: *Self, value: u32) void {
        self.h[0].raw = @truncate(u16, value);
        self.h[1].raw = @truncate(u16, value >> 16);
    }

    pub fn setV(self: *Self, value: u32) void {
        self.v[0].raw = @truncate(u16, value);
        self.v[1].raw = @truncate(u16, value >> 16);
    }

    pub fn setIo(self: *Self, value: u32) void {
        self.in.raw = @truncate(u16, value);
        self.out.raw = @truncate(u16, value >> 16);
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

    /// For whatever reason, some higher bits of BG0CNT
    /// are masked out
    pub inline fn bg0Cnt(self: *const Self) u16 {
        return self.cnt.raw & 0xDFFF;
    }

    /// BG1CNT inherits the same mask as BG0CNTs
    pub inline fn bg1Cnt(self: *const Self) u16 {
        return self.bg0Cnt();
    }
};

const AffineBackground = struct {
    const Self = @This();

    x: i32,
    y: i32,

    pa: i16,
    pb: i16,
    pc: i16,
    pd: i16,

    x_latch: ?i32,
    y_latch: ?i32,

    fn init() Self {
        return .{
            .x = 0,
            .y = 0,
            .pa = 0,
            .pb = 0,
            .pc = 0,
            .pd = 0,

            .x_latch = null,
            .y_latch = null,
        };
    }

    pub fn setX(self: *Self, is_vblank: bool, value: u32) void {
        self.x = @bitCast(i32, value);
        if (!is_vblank) self.x_latch = @bitCast(i32, value);
    }

    pub fn setY(self: *Self, is_vblank: bool, value: u32) void {
        self.y = @bitCast(i32, value);
        if (!is_vblank) self.y_latch = @bitCast(i32, value);
    }

    pub fn writePaPb(self: *Self, value: u32) void {
        self.pa = @bitCast(i16, @truncate(u16, value));
        self.pb = @bitCast(i16, @truncate(u16, value >> 16));
    }

    pub fn writePcPd(self: *Self, value: u32) void {
        self.pc = @bitCast(i16, @truncate(u16, value));
        self.pd = @bitCast(i16, @truncate(u16, value >> 16));
    }

    // Every Vblank BG?X/Y registers are latched
    fn latchRefPoints(self: *Self) void {
        self.x_latch = self.x;
        self.y_latch = self.y;
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

    fn is8bpp(self: *const Self) bool {
        return self.attr0.is_8bpp.read();
    }

    fn tileId(self: *const Self) u10 {
        return self.attr2.tile_id.read();
    }

    fn palBank(self: *const Self) u4 {
        return self.attr2.pal_bank.read();
    }

    fn hFlip(self: *const Self) bool {
        return self.attr1.h_flip.read();
    }

    fn vFlip(self: *const Self) bool {
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

    fn from(sprite: Sprite) AffineSprite {
        return .{
            .attr0 = .{ .raw = sprite.attr0.raw },
            .attr1 = .{ .raw = sprite.attr1.raw },
            .attr2 = sprite.attr2,
            .width = sprite.width,
            .height = sprite.height,
        };
    }

    fn x(self: *const Self) u9 {
        return self.attr1.x.read();
    }

    fn y(self: *const Self) u8 {
        return self.attr0.y.read();
    }

    fn is8bpp(self: *const Self) bool {
        return self.attr0.is_8bpp.read();
    }

    fn tileId(self: *const Self) u10 {
        return self.attr2.tile_id.read();
    }

    fn palBank(self: *const Self) u4 {
        return self.attr2.pal_bank.read();
    }

    fn matrixId(self: *const Self) u5 {
        return self.attr1.aff_sel.read();
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
    raw: u16,
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

inline fn rgba888(bgr555: u16) u32 {
    const b = @as(u32, bgr555 >> 10 & 0x1F);
    const g = @as(u32, bgr555 >> 5 & 0x1F);
    const r = @as(u32, bgr555 & 0x1F);

    return (r << 3 | r >> 2) << 24 | (g << 3 | g >> 2) << 16 | (b << 3 | b >> 2) << 8 | 0xFF;
}

fn alphaBlend(top: u16, btm: u16, bldalpha: io.BldAlpha) u16 {
    const eva: u16 = bldalpha.eva.read();
    const evb: u16 = bldalpha.evb.read();

    const top_r = top & 0x1F;
    const top_g = (top >> 5) & 0x1F;
    const top_b = (top >> 10) & 0x1F;

    const btm_r = btm & 0x1F;
    const btm_g = (btm >> 5) & 0x1F;
    const btm_b = (btm >> 10) & 0x1F;

    const bld_r = std.math.min(31, (top_r * eva + btm_r * evb) >> 4);
    const bld_g = std.math.min(31, (top_g * eva + btm_g * evb) >> 4);
    const bld_b = std.math.min(31, (top_b * eva + btm_b * evb) >> 4);

    return (bld_b << 10) | (bld_g << 5) | bld_r;
}

fn shouldDrawBackground(comptime n: u2, bldcnt: io.BldCnt, scanline: *Scanline, i: usize) bool {
    // If a pixel has been drawn on the top layer, it's because
    // Either the pixel is to be blended with a pixel on the bottom layer
    // or the pixel is not to be blended at all
    // Consequentially, if we find a pixel on the top layer, there's no need
    // to render anything I think?
    if (scanline.top()[i] != null) return false;

    if (scanline.btm()[i] != null) {
        // The Pixel found in the Bottom layer is
        // 1. From a higher priority
        // 2. From a Backround that is marked for Blending (Pixel A)
        //
        // We now have to confirm whether this current Background can be used
        // as Pixel B or not.

        // If Alpha Blending isn't enabled, we've aready found a higher
        // priority pixel to render. Move on
        if (bldcnt.mode.read() != 0b01) return false;

        const b_layers = bldcnt.layer_b.read();
        const is_blend_enabled = (b_layers >> n) & 1 == 1;

        // If the Background is not marked for blending, we've already found
        // a higher priority pixel, move on.
        if (!is_blend_enabled) return false;
    }

    return true;
}

fn shouldDrawSprite(bldcnt: io.BldCnt, scanline: *Scanline, x: u9) bool {
    if (scanline.top()[x] != null) return false;

    if (scanline.btm()[x] != null) {
        if (bldcnt.mode.read() != 0b01) return false;

        const b_layers = bldcnt.layer_b.read();
        const is_blend_enabled = (b_layers >> 4) & 1 == 1;
        if (!is_blend_enabled) return false;
    }

    return true;
}

fn copyToBackgroundBuffer(comptime n: u2, bldcnt: io.BldCnt, scanline: *Scanline, i: usize, bgr555: u16) void {
    if (bldcnt.mode.read() != 0b00) {
        // Standard Alpha Blending
        const a_layers = bldcnt.layer_a.read();
        const is_blend_enabled = (a_layers >> n) & 1 == 1;

        // If Alpha Blending is enabled and we've found an eligible layer for
        // Pixel A, store the pixel in the bottom pixel buffer
        if (is_blend_enabled) {
            scanline.btm()[i] = bgr555;
            return;
        }
    }

    scanline.top()[i] = bgr555;
}

fn copyToSpriteBuffer(bldcnt: io.BldCnt, scanline: *Scanline, x: u9, bgr555: u16) void {
    if (bldcnt.mode.read() != 0b00) {
        // Alpha Blending
        const a_layers = bldcnt.layer_a.read();
        const is_blend_enabled = (a_layers >> 4) & 1 == 1;

        if (is_blend_enabled) {
            scanline.btm()[x] = bgr555;
            return;
        }
    }

    scanline.top()[x] = bgr555;
}

const Scanline = struct {
    const Self = @This();

    layers: [2][]?u16,
    buf: []?u16,

    allocator: Allocator,

    fn init(allocator: Allocator) !Self {
        const buf = try allocator.alloc(?u16, width * 2); // Top & Bottom Scanline
        std.mem.set(?u16, buf, null);

        return .{
            // Top & Bototm Layers
            .layers = [_][]?u16{ buf[0..][0..width], buf[width..][0..width] },
            .buf = buf,
            .allocator = allocator,
        };
    }

    fn reset(self: *Self) void {
        std.mem.set(?u16, self.buf, null);
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.buf);
        self.* = undefined;
    }

    fn top(self: *Self) []?u16 {
        return self.layers[0];
    }

    fn btm(self: *Self) []?u16 {
        return self.layers[1];
    }
};

// Double Buffering Implementation
const FrameBuffer = struct {
    const Self = @This();

    layers: [2][]u8,
    buf: []u8,
    current: u1,

    allocator: Allocator,

    // TODO: Rename
    const Device = enum {
        Emulator,
        Renderer,
    };

    pub fn init(allocator: Allocator) !Self {
        const framebuf_len = framebuf_pitch * height;
        const buf = try allocator.alloc(u8, framebuf_len * 2);
        std.mem.set(u8, buf, 0);

        return .{
            // Front and Back Framebuffers
            .layers = [_][]u8{ buf[0..][0..framebuf_len], buf[framebuf_len..][0..framebuf_len] },
            .buf = buf,
            .current = 0,

            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.buf);
        self.* = undefined;
    }

    pub fn swap(self: *Self) void {
        self.current = ~self.current;
    }

    pub fn get(self: *Self, comptime dev: Device) []u8 {
        return self.layers[if (dev == .Emulator) self.current else ~self.current];
    }
};
