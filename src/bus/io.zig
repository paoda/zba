const std = @import("std");
const builtin = @import("builtin");

const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Bus = @import("../Bus.zig");
const DmaController = @import("dma.zig").DmaController;
const Scheduler = @import("../scheduler.zig").Scheduler;

const timer = @import("timer.zig");
const dma = @import("dma.zig");
const apu = @import("../apu.zig");

const readUndefined = @import("../util.zig").readUndefined;
const writeUndefined = @import("../util.zig").writeUndefined;
const log = std.log.scoped(.@"I/O");

pub const Io = struct {
    const Self = @This();

    /// Read / Write
    ime: bool,
    ie: InterruptEnable,
    irq: InterruptRequest,
    postflg: PostFlag,
    haltcnt: HaltControl,
    keyinput: KeyInput,

    pub fn init() Self {
        return .{
            .ime = false,
            .ie = .{ .raw = 0x0000 },
            .irq = .{ .raw = 0x0000 },
            .keyinput = .{ .raw = 0x03FF },
            .postflg = .FirstBoot,
            .haltcnt = .Execute,
        };
    }

    fn setIrqs(self: *Io, word: u32) void {
        self.ie.raw = @truncate(u16, word);
        self.irq.raw &= ~@truncate(u16, word >> 16);
    }
};

pub fn read(bus: *const Bus, comptime T: type, address: u32) T {
    return switch (T) {
        u32 => switch (address) {
            // Display
            0x0400_0000 => bus.ppu.dispcnt.raw,
            0x0400_0004 => @as(T, bus.ppu.vcount.raw) << 16 | bus.ppu.dispstat.raw,
            0x0400_0006 => @as(T, bus.ppu.bg[0].cnt.raw) << 16 | bus.ppu.vcount.raw,

            // DMA Transfers
            0x0400_00B8...0x0400_00DC => dma.read(T, &bus.dma, address),

            // Timers
            0x0400_0100...0x0400_010C => timer.read(T, &bus.tim, address),

            // Serial Communication 1
            0x0400_0128 => readTodo("Read {} from SIOCNT and SIOMLT_SEND", .{T}),

            // Keypad Input
            0x0400_0130 => readTodo("Read {} from KEYINPUT", .{T}),

            // Serial Communication 2
            0x0400_0150 => readTodo("Read {} from JOY_RECV", .{T}),

            // Interrupts
            0x0400_0200 => @as(T, bus.io.irq.raw) << 16 | bus.io.ie.raw,
            0x0400_0208 => @boolToInt(bus.io.ime),
            else => readUndefined(log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, address }),
        },
        u16 => switch (address) {
            // Display
            0x0400_0000 => bus.ppu.dispcnt.raw,
            0x0400_0004 => bus.ppu.dispstat.raw,
            0x0400_0006 => bus.ppu.vcount.raw,
            0x0400_0008 => bus.ppu.bg[0].cnt.raw,
            0x0400_000A => bus.ppu.bg[1].cnt.raw,
            0x0400_000C => bus.ppu.bg[2].cnt.raw,
            0x0400_000E => bus.ppu.bg[3].cnt.raw,
            0x0400_004C => readTodo("Read {} from MOSAIC", .{T}),

            // Sound
            0x0400_0060...0x0400_009F => apu.read(T, &bus.apu, address),

            // DMA Transfers
            0x0400_00BA...0x0400_00DE => dma.read(T, &bus.dma, address),

            // Timers
            0x0400_0100...0x0400_010E => timer.read(T, &bus.tim, address),

            // Serial Communication 1
            0x0400_0128 => readTodo("Read {} from SIOCNT", .{T}),

            // Keypad Input
            0x0400_0130 => bus.io.keyinput.raw,

            // Serial Communication 2
            0x0400_0134 => readTodo("Read {} from RCNT", .{T}),

            // Interrupts
            0x0400_0200 => bus.io.ie.raw,
            0x0400_0202 => bus.io.irq.raw,
            0x0400_0204 => readTodo("Read {} from WAITCNT", .{T}),
            0x0400_0208 => @boolToInt(bus.io.ime),
            else => readUndefined(log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, address }),
        },
        u8 => return switch (address) {
            // Display
            0x0400_0000 => @truncate(T, bus.ppu.dispcnt.raw),
            0x0400_0004 => @truncate(T, bus.ppu.dispstat.raw),
            0x0400_0005 => @truncate(T, bus.ppu.dispcnt.raw >> 8),
            0x0400_0006 => @truncate(T, bus.ppu.vcount.raw),
            0x0400_0008 => @truncate(T, bus.ppu.bg[0].cnt.raw),
            0x0400_0009 => @truncate(T, bus.ppu.bg[0].cnt.raw >> 8),
            0x0400_000A => @truncate(T, bus.ppu.bg[1].cnt.raw),
            0x0400_000B => @truncate(T, bus.ppu.bg[1].cnt.raw >> 8),

            // Sound
            0x0400_0060...0x0400_0089 => apu.read(T, &bus.apu, address),

            // Serial Communication 1
            0x0400_0128 => readTodo("Read {} from SIOCNT_L", .{T}),

            // Keypad Input
            0x0400_0130 => readTodo("read {} from KEYINPUT_L", .{T}),

            // Serial Communication 2
            0x0400_0135 => readTodo("Read {} from RCNT_H", .{T}),

            // Interrupts
            0x0400_0200 => @truncate(T, bus.io.ie.raw),
            0x0400_0300 => @enumToInt(bus.io.postflg),
            else => readUndefined(log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, address }),
        },
        else => @compileError("I/O: Unsupported read width"),
    };
}

pub fn write(bus: *Bus, comptime T: type, address: u32, value: T) void {
    return switch (T) {
        u32 => switch (address) {
            // Display
            0x0400_0000 => bus.ppu.dispcnt.raw = @truncate(u16, value),
            0x0400_0004 => {
                bus.ppu.dispstat.raw = @truncate(u16, value);
                bus.ppu.vcount.raw = @truncate(u16, value >> 16);
            },
            0x0400_0008 => bus.ppu.setAdjCnts(0, value),
            0x0400_000C => bus.ppu.setAdjCnts(2, value),
            0x0400_0010 => bus.ppu.setBgOffsets(0, value),
            0x0400_0014 => bus.ppu.setBgOffsets(1, value),
            0x0400_0018 => bus.ppu.setBgOffsets(2, value),
            0x0400_001C => bus.ppu.setBgOffsets(3, value),
            0x0400_0020 => bus.ppu.aff_bg[0].writePaPb(value),
            0x0400_0024 => bus.ppu.aff_bg[0].writePcPd(value),
            0x0400_0028 => bus.ppu.aff_bg[0].setX(bus.ppu.dispstat.vblank.read(), value),
            0x0400_002C => bus.ppu.aff_bg[0].setY(bus.ppu.dispstat.vblank.read(), value),
            0x0400_0030 => bus.ppu.aff_bg[1].writePaPb(value),
            0x0400_0034 => bus.ppu.aff_bg[1].writePcPd(value),
            0x0400_0038 => bus.ppu.aff_bg[1].setX(bus.ppu.dispstat.vblank.read(), value),
            0x0400_003C => bus.ppu.aff_bg[1].setY(bus.ppu.dispstat.vblank.read(), value),
            0x0400_0040 => log.debug("Wrote 0x{X:0>8} to WIN0H and WIN1H", .{value}),
            0x0400_0044 => log.debug("Wrote 0x{X:0>8} to WIN0V and WIN1V", .{value}),
            0x0400_0048 => log.debug("Wrote 0x{X:0>8} to WININ and WINOUT", .{value}),
            0x0400_004C => log.debug("Wrote 0x{X:0>8} to MOSAIC", .{value}),
            0x0400_0050 => log.debug("Wrote 0x{X:0>8} to BLDCNT and BLDALPHA", .{value}),
            0x0400_0054 => log.debug("Wrote 0x{X:0>8} to BLDY", .{value}),
            0x0400_0058...0x0400_005C => {}, // Unused

            // Sound
            0x0400_0060...0x0400_00A4 => apu.write(T, &bus.apu, address, value),
            0x0400_00A8, 0x0400_00AC => {}, // Unused

            // DMA Transfers
            0x0400_00B0...0x0400_00DC => dma.write(T, &bus.dma, address, value),
            0x0400_00E0...0x0400_00FC => {}, // Unused

            // Timers
            0x0400_0100...0x0400_010C => timer.write(T, &bus.tim, address, value),
            0x0400_0110...0x0400_011C => {}, // Unused

            // Serial Communication 1
            0x0400_0120 => log.debug("Wrote 0x{X:0>8} to SIODATA32/(SIOMULTI0 and SIOMULTI1)", .{value}),
            0x0400_0124 => log.debug("Wrote 0x{X:0>8} to SIOMULTI2 and SIOMULTI3", .{value}),
            0x0400_0128 => log.debug("Wrote 0x{X:0>8} to SIOCNT and SIOMLT_SEND/SIODATA8", .{value}),
            0x0400_012C => {}, // Unused

            // Keypad Input
            0x0400_0130 => log.debug("Wrote 0x{X:0>8} to KEYINPUT and KEYCNT", .{value}),

            // Serial Communication 2
            0x0400_0140 => log.debug("Wrote 0x{X:0>8} to JOYCNT", .{value}),
            0x0400_0150 => log.debug("Wrote 0x{X:0>8} to JOY_RECV", .{value}),
            0x0400_0154 => log.debug("Wrote 0x{X:0>8} to JOY_TRANS", .{value}),
            0x0400_0158 => log.debug("Wrote 0x{X:0>8} to JOYSTAT (?)", .{value}),
            0x0400_0144...0x0400_014C, 0x0400_015C => {}, // Unused

            // Interrupts
            0x0400_0200 => bus.io.setIrqs(value),
            0x0400_0204 => log.debug("Wrote 0x{X:0>8} to WAITCNT", .{value}),
            0x0400_0208 => bus.io.ime = value & 1 == 1,
            0x0400_020C...0x0400_021C => {}, // Unused
            else => writeUndefined(log, "Tried to write 0x{X:0>8}{} to 0x{X:0>8}", .{ value, T, address }),
        },
        u16 => switch (address) {
            // Display
            0x0400_0000 => bus.ppu.dispcnt.raw = value,
            0x0400_0004 => bus.ppu.dispstat.raw = value,
            0x0400_0006 => {}, // vcount is read-only
            0x0400_0008 => bus.ppu.bg[0].cnt.raw = value,
            0x0400_000A => bus.ppu.bg[1].cnt.raw = value,
            0x0400_000C => bus.ppu.bg[2].cnt.raw = value,
            0x0400_000E => bus.ppu.bg[3].cnt.raw = value,
            0x0400_0010 => bus.ppu.bg[0].hofs.raw = value, // TODO: Don't write out every HOFS / VOFS?
            0x0400_0012 => bus.ppu.bg[0].vofs.raw = value,
            0x0400_0014 => bus.ppu.bg[1].hofs.raw = value,
            0x0400_0016 => bus.ppu.bg[1].vofs.raw = value,
            0x0400_0018 => bus.ppu.bg[2].hofs.raw = value,
            0x0400_001A => bus.ppu.bg[2].vofs.raw = value,
            0x0400_001C => bus.ppu.bg[3].hofs.raw = value,
            0x0400_001E => bus.ppu.bg[3].vofs.raw = value,
            0x0400_0020 => bus.ppu.aff_bg[0].pa = @bitCast(i16, value),
            0x0400_0022 => bus.ppu.aff_bg[0].pb = @bitCast(i16, value),
            0x0400_0024 => bus.ppu.aff_bg[0].pc = @bitCast(i16, value),
            0x0400_0026 => bus.ppu.aff_bg[0].pd = @bitCast(i16, value),
            0x0400_0028 => bus.ppu.aff_bg[0].x = @bitCast(i32, @bitCast(u32, bus.ppu.aff_bg[0].x) & 0xFFFF_0000 | value),
            0x0400_002A => bus.ppu.aff_bg[0].x = @bitCast(i32, @bitCast(u32, bus.ppu.aff_bg[0].x) & 0x0000_FFFF | (@as(u32, value) << 16)),
            0x0400_002C => bus.ppu.aff_bg[0].y = @bitCast(i32, @bitCast(u32, bus.ppu.aff_bg[0].y) & 0xFFFF_0000 | value),
            0x0400_002E => bus.ppu.aff_bg[0].y = @bitCast(i32, @bitCast(u32, bus.ppu.aff_bg[0].y) & 0x0000_FFFF | (@as(u32, value) << 16)),
            0x0400_0030 => bus.ppu.aff_bg[1].pa = @bitCast(i16, value),
            0x0400_0032 => bus.ppu.aff_bg[1].pb = @bitCast(i16, value),
            0x0400_0034 => bus.ppu.aff_bg[1].pc = @bitCast(i16, value),
            0x0400_0036 => bus.ppu.aff_bg[1].pd = @bitCast(i16, value),
            0x0400_0038 => bus.ppu.aff_bg[1].x = @bitCast(i32, @bitCast(u32, bus.ppu.aff_bg[1].x) & 0xFFFF_0000 | value),
            0x0400_003A => bus.ppu.aff_bg[1].x = @bitCast(i32, @bitCast(u32, bus.ppu.aff_bg[1].x) & 0x0000_FFFF | (@as(u32, value) << 16)),
            0x0400_003C => bus.ppu.aff_bg[1].y = @bitCast(i32, @bitCast(u32, bus.ppu.aff_bg[1].y) & 0xFFFF_0000 | value),
            0x0400_003E => bus.ppu.aff_bg[1].y = @bitCast(i32, @bitCast(u32, bus.ppu.aff_bg[1].y) & 0x0000_FFFF | (@as(u32, value) << 16)),
            0x0400_0040 => log.debug("Wrote 0x{X:0>4} to WIN0H", .{value}),
            0x0400_0042 => log.debug("Wrote 0x{X:0>4} to WIN1H", .{value}),
            0x0400_0044 => log.debug("Wrote 0x{X:0>4} to WIN0V", .{value}),
            0x0400_0046 => log.debug("Wrote 0x{X:0>4} to WIN1V", .{value}),
            0x0400_0048 => log.debug("Wrote 0x{X:0>4} to WININ", .{value}),
            0x0400_004A => log.debug("Wrote 0x{X:0>4} to WINOUT", .{value}),
            0x0400_004C => log.debug("Wrote 0x{X:0>4} to MOSAIC", .{value}),
            0x0400_0050 => log.debug("Wrote 0x{X:0>4} to BLDCNT", .{value}),
            0x0400_0052 => log.debug("Wrote 0x{X:0>4} to BLDALPHA", .{value}),
            0x0400_0054 => log.debug("Wrote 0x{X:0>4} to BLDY", .{value}),
            0x0400_004E, 0x0400_0056 => {}, // Not used

            // Sound
            0x0400_0060...0x0400_009F => apu.write(T, &bus.apu, address, value),

            // Dma Transfers
            0x0400_00B0...0x0400_00DE => dma.write(T, &bus.dma, address, value),

            // Timers
            0x0400_0100...0x0400_010E => timer.write(T, &bus.tim, address, value),
            0x0400_0114 => {}, // TODO: Gyakuten Saiban writes 0x8000 to 0x0400_0114
            0x0400_0110 => {}, // Not Used,

            // Serial Communication 1
            0x0400_0120 => log.debug("Wrote 0x{X:0>4} to SIOMULTI0", .{value}),
            0x0400_0122 => log.debug("Wrote 0x{X:0>4} to SIOMULTI1", .{value}),
            0x0400_0124 => log.debug("Wrote 0x{X:0>4} to SIOMULTI2", .{value}),
            0x0400_0126 => log.debug("Wrote 0x{X:0>4} to SIOMULTI3", .{value}),
            0x0400_0128 => log.debug("Wrote 0x{X:0>4} to SIOCNT", .{value}),
            0x0400_012A => log.debug("Wrote 0x{X:0>4} to SIOMLT_SEND", .{value}),

            // Keypad Input
            0x0400_0130 => log.debug("Wrote 0x{X:0>4} to KEYINPUT. Ignored", .{value}),
            0x0400_0132 => log.debug("Wrote 0x{X:0>4} to KEYCNT", .{value}),

            // Serial Communication 2
            0x0400_0134 => log.debug("Wrote 0x{X:0>4} to RCNT", .{value}),
            0x0400_0140 => log.debug("Wrote 0x{X:0>4} to JOYCNT", .{value}),
            0x0400_0158 => log.debug("Wrote 0x{X:0>4} to JOYSTAT", .{value}),
            0x0400_0142, 0x0400_015A => {}, // Not Used

            // Interrupts
            0x0400_0200 => bus.io.ie.raw = value,
            0x0400_0202 => bus.io.irq.raw &= ~value,
            0x0400_0204 => log.debug("Wrote 0x{X:0>4} to WAITCNT", .{value}),
            0x0400_0208 => bus.io.ime = value & 1 == 1,
            0x0400_0206, 0x0400_020A => {}, // Not Used
            else => writeUndefined(log, "Tried to write 0x{X:0>4}{} to 0x{X:0>8}", .{ value, T, address }),
        },
        u8 => switch (address) {
            // Display
            0x0400_0004 => bus.ppu.dispstat.raw = (bus.ppu.dispstat.raw & 0xFF00) | value,
            0x0400_0005 => bus.ppu.dispstat.raw = (@as(u16, value) << 8) | (bus.ppu.dispstat.raw & 0xFF),
            0x0400_0008 => bus.ppu.bg[0].cnt.raw = (bus.ppu.bg[0].cnt.raw & 0xFF00) | value,
            0x0400_0009 => bus.ppu.bg[0].cnt.raw = (@as(u16, value) << 8) | (bus.ppu.bg[0].cnt.raw & 0xFF),
            0x0400_000A => bus.ppu.bg[1].cnt.raw = (bus.ppu.bg[1].cnt.raw & 0xFF00) | value,
            0x0400_000B => bus.ppu.bg[1].cnt.raw = (@as(u16, value) << 8) | (bus.ppu.bg[1].cnt.raw & 0xFF),
            0x0400_0048 => log.debug("Wrote 0x{X:0>2} to WININ_L", .{value}),
            0x0400_0049 => log.debug("Wrote 0x{X:0>2} to WININ_H", .{value}),
            0x0400_004A => log.debug("Wrote 0x{X:0>2} to WINOUT_L", .{value}),
            0x0400_0054 => log.debug("Wrote 0x{X:0>2} to BLDY_L", .{value}),

            // Sound
            0x0400_0060...0x0400_009F => apu.write(T, &bus.apu, address, value),

            // Serial Communication 1
            0x0400_0120 => log.debug("Wrote 0x{X:0>2} to SIODATA32_L_L", .{value}),
            0x0400_0128 => log.debug("Wrote 0x{X:0>2} to SIOCNT_L", .{value}),

            // Serial Communication 2
            0x0400_0135 => log.debug("Wrote 0x{X:0>2} to RCNT_H", .{value}),
            0x0400_0140 => log.debug("Wrote 0x{X:0>2} to JOYCNT_L", .{value}),

            // Interrupts
            0x0400_0202 => bus.io.irq.raw &= ~@as(u16, value),
            0x0400_0208 => bus.io.ime = value & 1 == 1,
            0x0400_0300 => bus.io.postflg = std.meta.intToEnum(PostFlag, value & 1) catch unreachable,
            0x0400_0301 => bus.io.haltcnt = if (value >> 7 & 1 == 0) .Halt else std.debug.panic("TODO: Implement STOP", .{}),

            0x0400_0410 => log.debug("Wrote 0x{X:0>2} to the common yet undocumented 0x{X:0>8}", .{ value, address }),
            else => writeUndefined(log, "Tried to write 0x{X:0>2}{} to 0x{X:0>8}", .{ value, T, address }),
        },
        else => @compileError("I/O: Unsupported write width"),
    };
}

fn readTodo(comptime format: []const u8, args: anytype) u8 {
    log.debug(format, args);
    return 0;
}

/// Read / Write
pub const PostFlag = enum(u1) {
    FirstBoot = 0,
    FurtherBoots = 1,
};

/// Write Only
pub const HaltControl = enum {
    Halt,
    Stop,
    Execute,
};

/// Read / Write
pub const DisplayControl = extern union {
    bg_mode: Bitfield(u16, 0, 3),
    frame_select: Bit(u16, 4),
    hblank_interval_free: Bit(u16, 5),
    obj_mapping: Bit(u16, 6),
    forced_blank: Bit(u16, 7),
    bg_enable: Bitfield(u16, 8, 4),
    obj_enable: Bit(u16, 12),
    win_enable: Bitfield(u16, 13, 2),
    obj_win_enable: Bit(u16, 15),
    raw: u16,
};

/// Read / Write
pub const DisplayStatus = extern union {
    vblank: Bit(u16, 0),
    hblank: Bit(u16, 1),
    coincidence: Bit(u16, 2),
    vblank_irq: Bit(u16, 3),
    hblank_irq: Bit(u16, 4),
    vcount_irq: Bit(u16, 5),
    vcount_trigger: Bitfield(u16, 8, 8),
    raw: u16,
};

/// Read Only
pub const VCount = extern union {
    scanline: Bitfield(u16, 0, 8),
    raw: u16,
};

/// Read / Write
const InterruptEnable = extern union {
    vblank: Bit(u16, 0),
    hblank: Bit(u16, 1),
    coincidence: Bit(u16, 2),
    tm0_overflow: Bit(u16, 3),
    tm1_overflow: Bit(u16, 4),
    tm2_overflow: Bit(u16, 5),
    tm3_overflow: Bit(u16, 6),
    serial: Bit(u16, 7),
    dma0: Bit(u16, 8),
    dma1: Bit(u16, 9),
    dma2: Bit(u16, 10),
    dma3: Bit(u16, 11),
    keypad: Bit(u16, 12),
    game_pak: Bit(u16, 13),
    raw: u16,
};

/// Read Only
/// 0 = Pressed, 1 = Released
const KeyInput = extern union {
    a: Bit(u16, 0),
    b: Bit(u16, 1),
    select: Bit(u16, 2),
    start: Bit(u16, 3),
    right: Bit(u16, 4),
    left: Bit(u16, 5),
    up: Bit(u16, 6),
    down: Bit(u16, 7),
    shoulder_r: Bit(u16, 8),
    shoulder_l: Bit(u16, 9),
    raw: u16,
};

// Read / Write
pub const BackgroundControl = extern union {
    priority: Bitfield(u16, 0, 2),
    char_base: Bitfield(u16, 2, 2),
    mosaic_enable: Bit(u16, 6),
    colour_mode: Bit(u16, 7),
    screen_base: Bitfield(u16, 8, 5),
    display_overflow: Bit(u16, 13),
    size: Bitfield(u16, 14, 2),
    raw: u16,
};

/// Write Only
pub const BackgroundOffset = extern union {
    offset: Bitfield(u16, 0, 9),
    raw: u16,
};

/// Read / Write
const InterruptRequest = extern union {
    vblank: Bit(u16, 0),
    hblank: Bit(u16, 1),
    coincidence: Bit(u16, 2),
    tim0_overflow: Bit(u16, 3),
    tim1_overflow: Bit(u16, 4),
    tim2_overflow: Bit(u16, 5),
    tim3_overflow: Bit(u16, 6),
    serial: Bit(u16, 7),
    dma0: Bit(u16, 8),
    dma1: Bit(u16, 9),
    dma2: Bit(u16, 10),
    dma3: Bit(u16, 11),
    keypad: Bit(u16, 12),
    game_pak: Bit(u16, 13),
    raw: u16,
};

/// Read / Write
pub const DmaControl = extern union {
    dad_adj: Bitfield(u16, 5, 2),
    sad_adj: Bitfield(u16, 7, 2),
    repeat: Bit(u16, 9),
    transfer_type: Bit(u16, 10),
    pak_drq: Bit(u16, 11),
    start_timing: Bitfield(u16, 12, 2),
    irq: Bit(u16, 14),
    enabled: Bit(u16, 15),
    raw: u16,
};

/// Read / Write
pub const TimerControl = extern union {
    frequency: Bitfield(u16, 0, 2),
    cascade: Bit(u16, 2),
    irq: Bit(u16, 6),
    enabled: Bit(u16, 7),
    raw: u16,
};

/// Read / Write
/// NR10
pub const Sweep = extern union {
    shift: Bitfield(u8, 0, 3),
    direction: Bit(u8, 3),
    period: Bitfield(u8, 4, 3),
    raw: u8,
};

/// Read / Write
/// This represents the Duty / Len
/// NRx1
pub const Duty = extern union {
    /// Write-only
    /// Only used when bit 6 is set
    length: Bitfield(u16, 0, 6),
    pattern: Bitfield(u16, 6, 2),
    raw: u8,
};

/// Read / Write
/// NRx2
pub const Envelope = extern union {
    period: Bitfield(u8, 0, 3),
    direction: Bit(u8, 3),
    init_vol: Bitfield(u8, 4, 4),
    raw: u8,
};

/// Read / Write
/// NRx3, NRx4
pub const Frequency = extern union {
    /// Write-only
    frequency: Bitfield(u16, 0, 11),
    length_enable: Bit(u16, 14),
    /// Write-only
    trigger: Bit(u16, 15),

    raw: u16,
};

/// Read / Write
/// NR30
pub const WaveSelect = extern union {
    dimension: Bit(u8, 5),
    bank: Bit(u8, 6),
    enabled: Bit(u8, 7),
    raw: u8,
};

/// Read / Write
/// NR32
pub const WaveVolume = extern union {
    kind: Bitfield(u8, 5, 2),
    force: Bit(u8, 7),
    raw: u8,
};

/// Read / Write
/// NR43
pub const PolyCounter = extern union {
    div_ratio: Bitfield(u8, 0, 3),
    width: Bit(u8, 3),
    shift: Bitfield(u8, 4, 4),
    raw: u8,
};

/// Read / Write
/// NR44
pub const NoiseControl = extern union {
    length_enable: Bit(u8, 6),
    trigger: Bit(u8, 7),
    raw: u8,
};

/// Read / Write
pub const ChannelVolumeControl = extern union {
    right_vol: Bitfield(u16, 0, 3),
    left_vol: Bitfield(u16, 4, 3),
    ch_right: Bitfield(u16, 8, 4),
    ch_left: Bitfield(u16, 12, 4),
    raw: u16,
};

/// Read / Write
pub const DmaSoundControl = extern union {
    ch_vol: Bitfield(u16, 0, 2),
    chA_vol: Bit(u16, 2),
    chB_vol: Bit(u16, 3),

    chA_right: Bit(u16, 8),
    chA_left: Bit(u16, 9),
    chA_timer: Bit(u16, 10),
    /// Write only?
    chA_reset: Bit(u16, 11),

    chB_right: Bit(u16, 12),
    chB_left: Bit(u16, 13),
    chB_timer: Bit(u16, 14),
    /// Write only?
    chB_reset: Bit(u16, 15),
    raw: u16,
};

/// Read / Write
pub const SoundControl = extern union {
    /// Read-only
    ch1_enable: Bit(u8, 0),
    /// Read-only
    ch2_enable: Bit(u8, 1),
    /// Read-only
    ch3_enable: Bit(u8, 2),
    /// Read-only
    ch4_enable: Bit(u8, 3),
    apu_enable: Bit(u8, 7),
    raw: u8,
};

/// Read / Write
pub const SoundBias = extern union {
    level: Bitfield(u16, 1, 9),
    sampling_cycle: Bitfield(u16, 14, 2),
    raw: u16,
};
