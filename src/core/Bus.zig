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
const DmaTuple = @import("bus/dma.zig").DmaTuple;
const TimerTuple = @import("bus/timer.zig").TimerTuple;
const Scheduler = @import("scheduler.zig").Scheduler;
const FilePaths = @import("util.zig").FilePaths;

const io = @import("bus/io.zig");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Bus);

const createDmaTuple = @import("bus/dma.zig").create;
const createTimerTuple = @import("bus/timer.zig").create;
const rotr = @import("util.zig").rotr;

const timings: [2][0x10]u8 = [_][0x10]u8{
    // BIOS, Unused, EWRAM, IWRAM, I/0, PALRAM, VRAM, OAM, ROM0, ROM0, ROM1, ROM1, ROM2, ROM2, SRAM, Unused
    [_]u8{ 1, 1, 3, 1, 1, 1, 1, 1, 5, 5, 5, 5, 5, 5, 5, 5 }, // 8-bit & 16-bit
    [_]u8{ 1, 1, 6, 1, 1, 2, 2, 1, 8, 8, 8, 8, 8, 8, 8, 8 }, // 32-bit
};

pub const fetch_timings: [2][0x10]u8 = [_][0x10]u8{
    // BIOS, Unused, EWRAM, IWRAM, I/0, PALRAM, VRAM, OAM, ROM0, ROM0, ROM1, ROM1, ROM2, ROM2, SRAM, Unused
    [_]u8{ 1, 1, 3, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 5, 5 }, // 8-bit & 16-bit
    [_]u8{ 1, 1, 6, 1, 1, 2, 2, 1, 4, 4, 4, 4, 4, 4, 8, 8 }, // 32-bit
};

const Self = @This();

pak: GamePak,
bios: Bios,
ppu: Ppu,
apu: Apu,
dma: DmaTuple,
tim: TimerTuple,
iwram: Iwram,
ewram: Ewram,
io: Io,

cpu: ?*Arm7tdmi,
sched: *Scheduler,

pub fn init(self: *Self, allocator: Allocator, sched: *Scheduler, cpu: *Arm7tdmi, paths: FilePaths) !void {
    self.* = .{
        .pak = try GamePak.init(allocator, paths.rom, paths.save),
        .bios = try Bios.init(allocator, paths.bios),
        .ppu = try Ppu.init(allocator, sched),
        .apu = Apu.init(sched),
        .iwram = try Iwram.init(allocator),
        .ewram = try Ewram.init(allocator),
        .dma = createDmaTuple(),
        .tim = createTimerTuple(sched),
        .io = Io.init(),
        .cpu = cpu,
        .sched = sched,
    };
}

pub fn deinit(self: *Self) void {
    self.iwram.deinit();
    self.ewram.deinit();
    self.pak.deinit();
    self.bios.deinit();
    self.ppu.deinit();
    self.* = undefined;
}

pub fn dbgRead(self: *const Self, comptime T: type, address: u32) T {
    const page = @truncate(u8, address >> 24);
    const aligned_addr = forceAlign(T, address);

    return switch (page) {
        // General Internal Memory
        0x00 => blk: {
            if (address < Bios.size)
                break :blk self.bios.dbgRead(T, self.cpu.?.r[15], aligned_addr);

            break :blk self.readOpenBus(T, address);
        },
        0x02 => self.ewram.read(T, aligned_addr),
        0x03 => self.iwram.read(T, aligned_addr),
        0x04 => io.read(self, T, aligned_addr),

        // Internal Display Memory
        0x05 => self.ppu.palette.read(T, aligned_addr),
        0x06 => self.ppu.vram.read(T, aligned_addr),
        0x07 => self.ppu.oam.read(T, aligned_addr),

        // External Memory (Game Pak)
        0x08...0x0D => self.pak.dbgRead(T, aligned_addr),
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
        else => self.readOpenBus(T, address),
    };
}

fn readOpenBus(self: *const Self, comptime T: type, address: u32) T {
    const r15 = self.cpu.?.r[15];

    const word = if (self.cpu.?.cpsr.t.read()) blk: {
        const page = @truncate(u8, r15 >> 24);

        switch (page) {
            // EWRAM, PALRAM, VRAM, and Game ROM (16-bit)
            0x02, 0x05, 0x06, 0x08...0x0D => {
                const halfword = self.dbgRead(u16, r15 + 2);
                break :blk @as(u32, halfword) << 16 | halfword;
            },
            // BIOS or OAM (32-bit)
            0x00, 0x07 => {
                const offset: u32 = if (address & 3 == 0b00) 2 else 0;
                break :blk @as(u32, self.dbgRead(u16, (r15 + 2) + offset)) << 16 | self.dbgRead(u16, r15 + offset);
            },
            // IWRAM (16-bit but special)
            0x03 => {
                const offset: u32 = if (address & 3 == 0b00) 2 else 0;
                break :blk @as(u32, self.dbgRead(u16, (r15 + 2) - offset)) << 16 | self.dbgRead(u16, r15 + offset);
            },
            else => unreachable,
        }
    } else self.dbgRead(u32, r15 + 4);

    return @truncate(T, rotr(u32, word, 8 * (address & 3)));
}

pub fn read(self: *Self, comptime T: type, address: u32) T {
    const page = @truncate(u8, address >> 24);
    const aligned_addr = forceAlign(T, address);

    self.sched.tick += timings[@boolToInt(T == u32)][@truncate(u4, page)];

    return switch (page) {
        // General Internal Memory
        0x00 => blk: {
            if (address < Bios.size)
                break :blk self.bios.read(T, self.cpu.?.r[15], aligned_addr);

            break :blk self.readOpenBus(T, address);
        },
        0x02 => self.ewram.read(T, aligned_addr),
        0x03 => self.iwram.read(T, aligned_addr),
        0x04 => io.read(self, T, aligned_addr),

        // Internal Display Memory
        0x05 => self.ppu.palette.read(T, aligned_addr),
        0x06 => self.ppu.vram.read(T, aligned_addr),
        0x07 => self.ppu.oam.read(T, aligned_addr),

        // External Memory (Game Pak)
        0x08...0x0D => self.pak.read(T, aligned_addr),
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
        else => self.readOpenBus(T, address),
    };
}

pub fn write(self: *Self, comptime T: type, address: u32, value: T) void {
    const page = @truncate(u8, address >> 24);
    const aligned_addr = forceAlign(T, address);

    self.sched.tick += timings[@boolToInt(T == u32)][@truncate(u4, page)];

    switch (page) {
        // General Internal Memory
        0x00 => self.bios.write(T, aligned_addr, value),
        0x02 => self.ewram.write(T, aligned_addr, value),
        0x03 => self.iwram.write(T, aligned_addr, value),
        0x04 => io.write(self, T, aligned_addr, value),

        // Internal Display Memory
        0x05 => self.ppu.palette.write(T, aligned_addr, value),
        0x06 => self.ppu.vram.write(T, self.ppu.dispcnt, aligned_addr, value),
        0x07 => self.ppu.oam.write(T, aligned_addr, value),

        // External Memory (Game Pak)
        0x08...0x0D => self.pak.write(T, self.dma[3].word_count, aligned_addr, value),
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

fn forceAlign(comptime T: type, address: u32) u32 {
    return switch (T) {
        u32 => address & 0xFFFF_FFFC,
        u16 => address & 0xFFFF_FFFE,
        u8 => address,
        else => @compileError("Bus: Invalid read/write type"),
    };
}
