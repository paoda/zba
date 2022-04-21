const std = @import("std");

const AudioDeviceId = @import("sdl2").SDL_AudioDeviceID;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Bios = @import("bus/Bios.zig");
const Ewram = @import("bus/Ewram.zig");
const GamePak = @import("bus/GamePak.zig");
const Io = @import("bus/io.zig").Io;
const Iwram = @import("bus/Iwram.zig");
const Ppu = @import("ppu.zig").Ppu;
const Apu = @import("apu.zig").Apu;
const DmaControllers = @import("bus/dma.zig").DmaControllers;
const Timers = @import("bus/timer.zig").Timers;
const Scheduler = @import("scheduler.zig").Scheduler;
const FilePaths = @import("util.zig").FilePaths;

const io = @import("bus/io.zig");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Bus);

const rotr = @import("util.zig").rotr;
const Self = @This();

const panic_on_und_bus: bool = false;

pak: GamePak,
bios: Bios,
ppu: Ppu,
apu: Apu,
dma: DmaControllers,
tim: Timers,
iwram: Iwram,
ewram: Ewram,
io: Io,

cpu: ?*Arm7tdmi,
sched: *Scheduler,

pub fn init(alloc: Allocator, sched: *Scheduler, paths: FilePaths) !Self {
    return Self{
        .pak = try GamePak.init(alloc, paths.rom, paths.save),
        .bios = try Bios.init(alloc, paths.bios),
        .ppu = try Ppu.init(alloc, sched),
        .apu = Apu.init(sched),
        .iwram = try Iwram.init(alloc),
        .ewram = try Ewram.init(alloc),
        .dma = DmaControllers.init(),
        .tim = Timers.init(sched),
        .io = Io.init(),
        .cpu = null,
        .sched = sched,
    };
}

pub fn deinit(self: Self) void {
    self.iwram.deinit();
    self.ewram.deinit();
    self.pak.deinit();
    self.bios.deinit();
    self.ppu.deinit();
}

pub fn attach(self: *Self, cpu: *Arm7tdmi) void {
    self.cpu = cpu;
}

pub fn handleDMATransfers(self: *Self) void {
    while (self.isDmaRunning()) {
        if (self.dma._1.step(self)) continue;
        if (self.dma._0.step(self)) continue;
        if (self.dma._2.step(self)) continue;
        if (self.dma._3.step(self)) continue;
    }
}

fn isDmaRunning(self: *const Self) bool {
    return self.dma._0.active or
        self.dma._1.active or
        self.dma._2.active or
        self.dma._3.active;
}

pub fn debugRead(self: *const Self, comptime T: type, address: u32) T {
    const cached = self.sched.tick;
    defer self.sched.tick = cached;

    return self.read(T, address);
}

fn readOpenBus(self: *const Self, comptime T: type, address: u32) T {
    const r15 = self.cpu.?.r[15];

    const word = if (self.cpu.?.cpsr.t.read()) blk: {
        const page = @truncate(u8, r15 >> 24);

        switch (page) {
            // EWRAM, PALRAM, VRAM, and Game ROM (16-bit)
            0x02, 0x05, 0x06, 0x08...0x0D => {
                const halfword = self.debugRead(u16, r15 + 2);
                break :blk @as(u32, halfword) << 16 | halfword;
            },
            // BIOS or OAM (32-bit)
            0x00, 0x07 => {
                const offset: u32 = if (address & 3 == 0b00) 2 else 0;
                break :blk @as(u32, self.debugRead(u16, (r15 + 2) + offset)) << 16 | self.debugRead(u16, r15 + offset);
            },
            // IWRAM (16-bit but special)
            0x03 => {
                const offset: u32 = if (address & 3 == 0b00) 2 else 0;
                break :blk @as(u32, self.debugRead(u16, (r15 + 2) - offset)) << 16 | self.debugRead(u16, r15 + offset);
            },
            else => unreachable,
        }
    } else self.debugRead(u32, r15 + 4);

    return @truncate(T, rotr(u32, word, 8 * (address & 3)));
}

fn readBios(self: *const Self, comptime T: type, address: u32) T {
    if (address < Bios.size) return self.bios.read(T, alignAddress(T, address));

    return self.readOpenBus(T, address);
}

pub fn read(self: *const Self, comptime T: type, address: u32) T {
    const page = @truncate(u8, address >> 24);
    const align_addr = alignAddress(T, address);
    self.sched.tick += 1;

    return switch (page) {
        // General Internal Memory
        0x00 => self.readBios(T, address),
        0x02 => self.ewram.read(T, align_addr),
        0x03 => self.iwram.read(T, align_addr),
        0x04 => io.read(self, T, align_addr),

        // Internal Display Memory
        0x05 => self.ppu.palette.read(T, align_addr),
        0x06 => self.ppu.vram.read(T, align_addr),
        0x07 => self.ppu.oam.read(T, align_addr),

        // External Memory (Game Pak)
        0x08...0x0D => self.pak.read(T, align_addr),
        0x0E...0x0F => blk: {
            const value = self.pak.backup.read(address);

            const multiplier = switch (T) {
                u32 => 0x01010101,
                u16 => 0x0101,
                u8 => 1,
                else => @compileError("Backup: Unsupported read width"),
            };

            break :blk @as(T, value) * multiplier;
        },
        else => readOpenBus(self, T, address),
    };
}

pub fn write(self: *Self, comptime T: type, address: u32, value: T) void {
    const page = @truncate(u8, address >> 24);
    const align_addr = alignAddress(T, address);
    self.sched.tick += 1;

    switch (page) {
        // General Internal Memory
        0x00 => self.bios.write(T, align_addr, value),
        0x02 => self.ewram.write(T, align_addr, value),
        0x03 => self.iwram.write(T, align_addr, value),
        0x04 => io.write(self, T, align_addr, value),

        // Internal Display Memory
        0x05 => self.ppu.palette.write(T, align_addr, value),
        0x06 => self.ppu.vram.write(T, self.ppu.dispcnt, align_addr, value),
        0x07 => self.ppu.oam.write(T, align_addr, value),

        // External Memory (Game Pak)
        0x08...0x0D => {}, // EEPROM
        0x0E...0x0F => {
            const rotate_by = switch (T) {
                u32 => address & 3,
                u16 => address & 1,
                u8 => 0,
                else => @compileError("Backup: Unsupported write width"),
            };

            self.pak.backup.write(address, @truncate(u8, rotr(T, value, 8 * rotate_by)));
        },
        else => {},
    }
}

fn alignAddress(comptime T: type, address: u32) u32 {
    return switch (T) {
        u32 => address & 0xFFFF_FFFC,
        u16 => address & 0xFFFF_FFFE,
        u8 => address,
        else => @compileError("Bus: Invalid read/write type"),
    };
}

fn undRead(comptime format: []const u8, args: anytype) u8 {
    if (panic_on_und_bus) std.debug.panic(format, args) else log.warn(format, args);
    return 0;
}

fn undWrite(comptime format: []const u8, args: anytype) void {
    if (panic_on_und_bus) std.debug.panic(format, args) else log.warn(format, args);
}
