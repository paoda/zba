const std = @import("std");
const io = @import("bus/io.zig");

const EventKind = @import("scheduler.zig").EventKind;
const Scheduler = @import("scheduler.zig").Scheduler;

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
                // Mode 0

            },
            0x3 => {
                const start = framebuf_pitch * @as(usize, scanline);
                const end = start + framebuf_pitch;

                std.mem.copy(u8, self.framebuf[start..end], self.vram.buf[start..end]);
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

                    self.framebuf[buf_start + j + 1] = self.palette.buf[id + 1];
                    self.framebuf[buf_start + j] = self.palette.buf[id];
                }
            },
            else => std.debug.panic("[PPU] TODO: Implement BG Mode {}", .{bg_mode}),
        }
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
