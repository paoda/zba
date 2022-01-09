const std = @import("std");

const EventKind = @import("scheduler.zig").EventKind;
const Io = @import("bus/io.zig").Io;
const Scheduler = @import("scheduler.zig").Scheduler;

const Allocator = std.mem.Allocator;
const width = 240;
const height = 160;
pub const buf_pitch = width * @sizeOf(u16);
const buf_len = buf_pitch * height;

pub const Ppu = struct {
    vram: Vram,
    palette: Palette,
    sched: *Scheduler,
    frame_buf: []u8,
    alloc: Allocator,

    pub fn init(alloc: Allocator, sched: *Scheduler) !@This() {
        // Queue first Hblank
        sched.push(.{ .kind = .Draw, .tick = sched.tick + 240 * 4 });

        return @This(){
            .vram = try Vram.init(alloc),
            .palette = try Palette.init(alloc),
            .sched = sched,
            .frame_buf = try alloc.alloc(u8, buf_len),
            .alloc = alloc,
        };
    }

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.frame_buf);
        self.vram.deinit();
        self.palette.deinit();
    }

    pub fn drawScanline(self: *@This(), io: *const Io) void {
        const bg_mode = io.dispcnt.bg_mode.read();
        const scanline = io.vcount.scanline.read();

        switch (bg_mode) {
            0x3 => {
                // Mode 3
                const start = buf_pitch * @as(usize, scanline);
                const end = start + buf_pitch;

                std.mem.copy(u8, self.frame_buf[start..end], self.vram.buf[start..end]);
            },
            else => std.debug.panic("[PPU] TODO: Implement BG Mode {}", .{bg_mode}),
        }
    }
};

const Palette = struct {
    buf: []u8,
    alloc: Allocator,

    fn init(alloc: Allocator) !@This() {
        return @This(){
            .buf = try alloc.alloc(u8, 0x400),
            .alloc = alloc,
        };
    }

    fn deinit(self: @This()) void {
        self.alloc.free(self.buf);
    }

    pub inline fn get32(self: *const @This(), idx: usize) u32 {
        return (@as(u32, self.get16(idx + 2)) << 16) | @as(u32, self.get16(idx));
    }

    pub inline fn set32(self: *@This(), idx: usize, word: u32) void {
        self.set16(idx + 2, @truncate(u16, word >> 16));
        self.set16(idx, @truncate(u16, word));
    }

    pub inline fn get16(self: *const @This(), idx: usize) u16 {
        return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
    }

    pub inline fn set16(self: *@This(), idx: usize, halfword: u16) void {
        self.buf[idx + 1] = @truncate(u8, halfword >> 8);
        self.buf[idx] = @truncate(u8, halfword);
    }

    pub inline fn get8(self: *const @This(), idx: usize) u8 {
        return self.buf[idx];
    }
};

const Vram = struct {
    buf: []u8,
    alloc: Allocator,

    fn init(alloc: Allocator) !@This() {
        return @This(){
            .buf = try alloc.alloc(u8, 0x18000),
            .alloc = alloc,
        };
    }

    fn deinit(self: @This()) void {
        self.alloc.free(self.buf);
    }

    pub inline fn get32(self: *const @This(), idx: usize) u32 {
        return (@as(u32, self.get16(idx + 2)) << 16) | @as(u32, self.get16(idx));
    }

    pub inline fn set32(self: *@This(), idx: usize, word: u32) void {
        self.set16(idx + 2, @truncate(u16, word >> 16));
        self.set16(idx, @truncate(u16, word));
    }

    pub inline fn get16(self: *const @This(), idx: usize) u16 {
        return (@as(u16, self.buf[idx + 1]) << 8) | @as(u16, self.buf[idx]);
    }

    pub inline fn set16(self: *@This(), idx: usize, halfword: u16) void {
        self.buf[idx + 1] = @truncate(u8, halfword >> 8);
        self.buf[idx] = @truncate(u8, halfword);
    }

    pub inline fn get8(self: *const @This(), idx: usize) u8 {
        return self.buf[idx];
    }
};
