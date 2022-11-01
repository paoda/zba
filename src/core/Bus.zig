const std = @import("std");

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
const FilePaths = @import("../util.zig").FilePaths;

const io = @import("bus/io.zig");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Bus);

const createDmaTuple = @import("bus/dma.zig").create;
const createTimerTuple = @import("bus/timer.zig").create;
const rotr = @import("../util.zig").rotr;

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

// Fastmem Related
const page_size = 1 * 0x400; // 1KiB
const address_space_size = 0x1000_0000;
const table_len = address_space_size / page_size;

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

cpu: *Arm7tdmi,
sched: *Scheduler,

read_table: *const [table_len]?*const anyopaque,
write_tables: [2]*const [table_len]?*anyopaque,
allocator: Allocator,

pub fn init(self: *Self, allocator: Allocator, sched: *Scheduler, cpu: *Arm7tdmi, paths: FilePaths) !void {
    const tables = try allocator.alloc(?*anyopaque, 3 * table_len); // Allocate all tables

    const read_table: *[table_len]?*const anyopaque = tables[0..table_len];
    const left_write: *[table_len]?*anyopaque = tables[table_len .. 2 * table_len];
    const right_write: *[table_len]?*anyopaque = tables[2 * table_len .. 3 * table_len];

    self.* = .{
        .pak = try GamePak.init(allocator, cpu, paths.rom, paths.save),
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

        .read_table = read_table,
        .write_tables = .{ left_write, right_write },
        .allocator = allocator,
    };

    // read_table, write_tables, and *Self are not restricted to the lifetime
    // of this init function so we can initialize our tables here
    fillReadTable(self, read_table);

    // Internal Display Memory behavious unusually on 8-bit reads
    // so we have two different tables depending on whether there's an 8-bit read or not
    fillWriteTable(u16, self, left_write); // T could also be u32 here
    fillWriteTable(u8, self, right_write);
}

pub fn deinit(self: *Self) void {
    self.iwram.deinit();
    self.ewram.deinit();
    self.pak.deinit();
    self.bios.deinit();
    self.ppu.deinit();

    // This is so I can deallocate the original `allocator.alloc`. I have to re-make the type
    // since I'm not keeping it around, This is very jank and bad though
    // FIXME: please figure out another way
    self.allocator.free(@ptrCast([*]const ?*anyopaque, self.write_tables[0][0..])[0 .. 3 * table_len]);
    self.* = undefined;
}

fn fillReadTable(bus: *Self, table: *[table_len]?*const anyopaque) void {
    const vramMirror = @import("ppu.zig").Vram.mirror;

    for (table) |*ptr, i| {
        const addr = page_size * i;

        ptr.* = switch (addr) {
            // General Internal Memory
            0x0000_0000...0x0000_3FFF => null, // BIOS has it's own checks
            0x0200_0000...0x02FF_FFFF => &bus.ewram.buf[addr & 0x3FFFF],
            0x0300_0000...0x03FF_FFFF => &bus.iwram.buf[addr & 0x7FFF],
            0x0400_0000...0x0400_03FF => null, // I/O

            // Internal Display Memory
            0x0500_0000...0x05FF_FFFF => &bus.ppu.palette.buf[addr & 0x3FF],
            0x0600_0000...0x06FF_FFFF => &bus.ppu.vram.buf[vramMirror(addr)],
            0x0700_0000...0x07FF_FFFF => &bus.ppu.oam.buf[addr & 0x3FF],

            // External Memory (Game Pak)
            0x0800_0000...0x0DFF_FFFF => fillTableExternalMemory(bus, addr),
            0x0E00_0000...0x0FFF_FFFF => null, // SRAM
            else => null,
        };
    }
}

fn fillWriteTable(comptime T: type, bus: *Self, table: *[table_len]?*const anyopaque) void {
    comptime std.debug.assert(T == u32 or T == u16 or T == u8);
    const vramMirror = @import("ppu.zig").Vram.mirror;

    for (table) |*ptr, i| {
        const addr = page_size * i;

        ptr.* = switch (addr) {
            // General Internal Memory
            0x0000_0000...0x0000_3FFF => null, // BIOS has it's own checks
            0x0200_0000...0x02FF_FFFF => &bus.ewram.buf[addr & 0x3FFFF],
            0x0300_0000...0x03FF_FFFF => &bus.iwram.buf[addr & 0x7FFF],
            0x0400_0000...0x0400_03FF => null, // I/O

            // Internal Display Memory
            // FIXME: Different table for different integer width writes?
            0x0500_0000...0x05FF_FFFF => if (T != u8) &bus.ppu.palette.buf[addr & 0x3FF] else null,
            0x0600_0000...0x06FF_FFFF => if (T != u8) &bus.ppu.vram.buf[vramMirror(addr)] else null,
            0x0700_0000...0x07FF_FFFF => if (T != u8) &bus.ppu.oam.buf[addr & 0x3FF] else null,

            // External Memory (Game Pak)
            0x0800_0000...0x0DFF_FFFF => null, // ROM
            0x0E00_0000...0x0FFF_FFFF => null, // SRAM
            else => null,
        };
    }
}

fn fillTableExternalMemory(bus: *Self, addr: usize) ?*anyopaque {
    // see `GamePak.zig` for more information about what conditions need to be true
    // so that a simple pointer dereference isn't possible

    const start_addr = addr;
    const end_addr = addr + page_size;

    const gpio_data = start_addr <= 0x0800_00C4 and 0x0800_00C4 < end_addr;
    const gpio_direction = start_addr <= 0x0800_00C6 and 0x0800_00C6 < end_addr;
    const gpio_control = start_addr <= 0x0800_00C8 and 0x0800_00C8 < end_addr;

    if (bus.pak.gpio.device.kind != .None and (gpio_data or gpio_direction or gpio_control)) {
        // We found a GPIO device, and this page a GPIO register. We want to handle this in slowmem
        return null;
    }

    if (bus.pak.backup.kind == .Eeprom) {
        if (bus.pak.buf.len > 0x100_000) {
            // We are using a "large" EEPROM which means that if the below check is true
            // this page has an address that's reserved for the EEPROM and therefore must
            // be handled in slowmem
            if (addr & 0x1FF_FFFF > 0x1FF_FEFF) return null;
        } else {
            // We are using a "small" EEPROM which means that if the below check is true
            // (that is, we're in the 0xD address page) then we must handle at least one
            // address in this page in slowmem
            if (@truncate(u4, addr >> 24) == 0xD) return null;
        }
    }

    // Finally, the GamePak has some unique behaviour for reads past the end of the ROM,
    // so those will be handled by slowmem as well
    const masked_addr = addr & 0x1FF_FFFF;
    if (masked_addr >= bus.pak.buf.len) return null;

    return &bus.pak.buf[masked_addr];
}

// TODO: Take advantage of fastmem here too?
pub fn dbgRead(self: *const Self, comptime T: type, unaligned_address: u32) T {
    const page = @truncate(u8, unaligned_address >> 24);
    const address = forceAlign(T, unaligned_address);

    return switch (page) {
        // General Internal Memory
        0x00 => blk: {
            if (address < Bios.size)
                break :blk self.bios.dbgRead(T, self.cpu.r[15], address);

            break :blk self.openBus(T, address);
        },
        0x02 => self.ewram.read(T, address),
        0x03 => self.iwram.read(T, address),
        0x04 => self.readIo(T, address),

        // Internal Display Memory
        0x05 => self.ppu.palette.read(T, address),
        0x06 => self.ppu.vram.read(T, address),
        0x07 => self.ppu.oam.read(T, address),

        // External Memory (Game Pak)
        0x08...0x0D => self.pak.dbgRead(T, address),
        0x0E...0x0F => blk: {
            const value = self.pak.backup.read(unaligned_address);

            const multiplier = switch (T) {
                u32 => 0x01010101,
                u16 => 0x0101,
                u8 => 1,
                else => @compileError("Backup: Unsupported read width"),
            };

            break :blk @as(T, value) * multiplier;
        },
        else => self.openBus(T, address),
    };
}

fn readIo(self: *const Self, comptime T: type, address: u32) T {
    return io.read(self, T, address) orelse self.openBus(T, address);
}

fn openBus(self: *const Self, comptime T: type, address: u32) T {
    const r15 = self.cpu.r[15];

    const word = blk: {
        // If Arm, get the most recently fetched instruction (PC + 8)
        //
        // FIXME: This is most likely a faulty assumption.
        // I think what *actually* happens is that the Bus has a latch for the most
        // recently fetched piece of data, which is then returned during Open Bus (also DMA open bus?)
        // I can "get away" with this because it's very statistically likely that the most recently latched value is
        // the most recently fetched instruction by the pipeline
        if (!self.cpu.cpsr.t.read()) break :blk self.cpu.pipe.stage[1].?;

        const page = @truncate(u8, r15 >> 24);

        // PC + 2 = stage[0]
        // PC + 4 = stage[1]
        // PC + 6 = Need a Debug Read for this?

        switch (page) {
            // EWRAM, PALRAM, VRAM, and Game ROM (16-bit)
            0x02, 0x05, 0x06, 0x08...0x0D => {
                const halfword: u32 = @truncate(u16, self.cpu.pipe.stage[1].?);
                break :blk halfword << 16 | halfword;
            },

            // BIOS or OAM (32-bit)
            0x00, 0x07 => {
                // Aligned: (PC + 6) | (PC + 4)
                // Unaligned: (PC + 4) | (PC + 2)
                const aligned = address & 3 == 0b00;

                // TODO: What to do on PC + 6?
                const high: u32 = if (aligned) self.dbgRead(u16, r15 + 4) else @truncate(u16, self.cpu.pipe.stage[1].?);
                const low: u32 = @truncate(u16, self.cpu.pipe.stage[@boolToInt(aligned)].?);

                break :blk high << 16 | low;
            },

            // IWRAM (16-bit but special)
            0x03 => {
                // Aligned: (PC + 2) | (PC + 4)
                // Unaligned: (PC + 4) | (PC + 2)
                const aligned = address & 3 == 0b00;

                const high: u32 = @truncate(u16, self.cpu.pipe.stage[1 - @boolToInt(aligned)].?);
                const low: u32 = @truncate(u16, self.cpu.pipe.stage[@boolToInt(aligned)].?);

                break :blk high << 16 | low;
            },
            else => {
                log.err("THUMB open bus read from 0x{X:0>2} page @0x{X:0>8}", .{ page, address });
                @panic("invariant most-likely broken");
            },
        }
    };

    return @truncate(T, word);
}

pub fn read(self: *Self, comptime T: type, unaligned_address: u32) T {
    const bits = @typeInfo(std.math.IntFittingRange(0, page_size - 1)).Int.bits;
    const page = unaligned_address >> bits;
    const offset = unaligned_address & (page_size - 1);

    // whether or not we do this in slowmem or fastmem, we should advance the scheduler
    self.sched.tick += timings[@boolToInt(T == u32)][@truncate(u4, page)];

    // We're doing some serious out-of-bounds open-bus reads
    if (page > table_len) return self.slowRead(T, unaligned_address);

    if (self.read_table[page]) |some_ptr| {
        // We have a pointer to a page, cast the pointer to it's underlying type
        const Ptr = [*]const T;
        const alignment = @alignOf(std.meta.Child(Ptr));
        const ptr = @ptrCast(Ptr, @alignCast(alignment, some_ptr));

        // Note: We don't check array length, since we force align the
        // lower bits of the address as the GBA would
        return ptr[forceAlign(T, offset) / @sizeOf(T)];
    }

    return self.slowRead(T, unaligned_address);
}

fn slowRead(self: *Self, comptime T: type, unaligned_address: u32) T {
    @setCold(true);

    const page = @truncate(u8, unaligned_address >> 24);
    const address = forceAlign(T, unaligned_address);

    return switch (page) {
        // General Internal Memory
        0x00 => blk: {
            if (address < Bios.size)
                break :blk self.bios.read(T, self.cpu.r[15], address);

            break :blk self.openBus(T, address);
        },
        0x02 => unreachable, // completely handled by fastmeme
        0x03 => unreachable, // completely handled by fastmeme
        0x04 => self.readIo(T, address),

        // Internal Display Memory
        0x05 => unreachable, // completely handled by fastmeme
        0x06 => unreachable, // completely handled by fastmeme
        0x07 => unreachable, // completely handled by fastmeme

        // External Memory (Game Pak)
        0x08...0x0D => self.pak.read(T, address),
        0x0E...0x0F => blk: {
            const value = self.pak.backup.read(unaligned_address);

            const multiplier = switch (T) {
                u32 => 0x01010101,
                u16 => 0x0101,
                u8 => 1,
                else => @compileError("Backup: Unsupported read width"),
            };

            break :blk @as(T, value) * multiplier;
        },
        else => self.openBus(T, address),
    };
}

pub fn write(self: *Self, comptime T: type, unaligned_address: u32, value: T) void {
    const bits = @typeInfo(std.math.IntFittingRange(0, page_size - 1)).Int.bits;
    const page = unaligned_address >> bits;
    const offset = unaligned_address & (page_size - 1);

    // whether or not we do this in slowmem or fastmem, we should advance the scheduler
    self.sched.tick += timings[@boolToInt(T == u32)][@truncate(u4, page)];

    // We're doing some serious out-of-bounds open-bus writes, they do nothing though
    if (page > table_len) return;

    if (self.write_tables[if (T == u8) 1 else 0][page]) |some_ptr| {
        // We have a pointer to a page, cast the pointer to it's underlying type
        const Ptr = [*]T;
        const alignment = @alignOf(std.meta.Child(Ptr));
        const ptr = @ptrCast(Ptr, @alignCast(alignment, some_ptr));

        // Note: We don't check array length, since we force align the
        // lower bits of the address as the GBA would
        ptr[forceAlign(T, offset) / @sizeOf(T)] = value;
    } else {
        // we can return early if this is an 8-bit OAM write
        if (T == u8 and @truncate(u8, unaligned_address) == 0x07) return;

        self.slowWrite(T, unaligned_address, value);
    }
}

pub fn slowWrite(self: *Self, comptime T: type, unaligned_address: u32, value: T) void {
    // @setCold(true);
    const page = @truncate(u8, unaligned_address >> 24);
    const address = forceAlign(T, unaligned_address);

    switch (page) {
        // General Internal Memory
        0x00 => self.bios.write(T, address, value),
        0x02 => unreachable, // completely handled by fastmem
        0x03 => unreachable, // completely handled by fastmem
        0x04 => io.write(self, T, address, value),

        // Internal Display Memory
        0x05 => self.ppu.palette.write(T, address, value),
        0x06 => self.ppu.vram.write(T, self.ppu.dispcnt, address, value),
        0x07 => unreachable, // completely handled by fastmem

        // External Memory (Game Pak)
        0x08...0x0D => self.pak.write(T, self.dma[3].word_count, address, value),
        0x0E...0x0F => self.pak.backup.write(unaligned_address, @truncate(u8, rotr(T, value, 8 * rotateBy(T, unaligned_address)))),
        else => {},
    }
}

inline fn rotateBy(comptime T: type, address: u32) u32 {
    return switch (T) {
        u32 => address & 3,
        u16 => address & 1,
        u8 => 0,
        else => @compileError("Backup: Unsupported write width"),
    };
}

inline fn forceAlign(comptime T: type, address: u32) u32 {
    return switch (T) {
        u32 => address & ~@as(u32, 3),
        u16 => address & ~@as(u32, 1),
        u8 => address,
        else => @compileError("Bus: Invalid read/write type"),
    };
}
