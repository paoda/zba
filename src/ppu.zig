const std = @import("std");

const EventKind = @import("scheduler.zig").EventKind;
const Scheduler = @import("scheduler.zig").Scheduler;

const Allocator = std.mem.Allocator;

pub const Ppu = struct {
    vram: Vram,
    palette: Palette,
    sched: *Scheduler,

    pub fn init(alloc: Allocator, sched: *Scheduler) !@This() {
        // Queue first Hblank
        sched.push(.{ .kind = .HBlank, .tick = sched.tick + 240 * 4 });

        return @This(){
            .vram = try Vram.init(alloc),
            .palette = try Palette.init(alloc),
            .sched = sched,
        };
    }

    pub fn deinit(self: @This()) void {
        self.vram.deinit();
        self.palette.deinit();
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
