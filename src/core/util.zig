const std = @import("std");
const builtin = @import("builtin");
const Log2Int = std.math.Log2Int;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

const allow_unhandled_io = @import("emu.zig").allow_unhandled_io;

// Sign-Extend value of type `T` to type `U`
pub fn sext(comptime T: type, comptime U: type, value: T) T {
    // U must have less bits than T
    comptime std.debug.assert(@typeInfo(U).Int.bits <= @typeInfo(T).Int.bits);

    const iT = std.meta.Int(.signed, @typeInfo(T).Int.bits);
    const ExtU = if (@typeInfo(U).Int.signedness == .unsigned) T else iT;
    const shift = @intCast(Log2Int(T), @typeInfo(T).Int.bits - @typeInfo(U).Int.bits);

    return @bitCast(T, @bitCast(iT, @as(ExtU, @truncate(U, value)) << shift) >> shift);
}

/// See https://godbolt.org/z/W3en9Eche
pub inline fn rotr(comptime T: type, x: T, r: anytype) T {
    if (@typeInfo(T).Int.signedness == .signed)
        @compileError("cannot rotate signed integer");

    const ar = @intCast(Log2Int(T), @mod(r, @typeInfo(T).Int.bits));
    return x >> ar | x << (1 +% ~ar);
}

pub const FpsTracker = struct {
    const Self = @This();

    fps: u32,
    count: std.atomic.Atomic(u32),
    timer: std.time.Timer,

    pub fn init() Self {
        return .{
            .fps = 0,
            .count = std.atomic.Atomic(u32).init(0),
            .timer = std.time.Timer.start() catch unreachable,
        };
    }

    pub fn tick(self: *Self) void {
        _ = self.count.fetchAdd(1, .Monotonic);
    }

    pub fn value(self: *Self) u32 {
        if (self.timer.read() >= std.time.ns_per_s) {
            self.fps = self.count.swap(0, .SeqCst);
            self.timer.reset();
        }

        return self.fps;
    }
};

pub fn intToBytes(comptime T: type, value: anytype) [@sizeOf(T)]u8 {
    comptime std.debug.assert(@typeInfo(T) == .Int);

    var result: [@sizeOf(T)]u8 = undefined;

    var i: Log2Int(T) = 0;
    while (i < result.len) : (i += 1) result[i] = @truncate(u8, value >> i * @bitSizeOf(u8));

    return result;
}

/// The Title from the GBA Cartridge may be null padded to a maximum
/// length of 12 bytes.
///
/// This function returns a slice of everything just before the first
/// `\0`
pub fn asStringSlice(title: *const [12]u8) []const u8 {
    var len = title.len;
    for (title) |char, i| {
        if (char == 0) {
            len = i;
            break;
        }
    }

    return title[0..len];
}

/// Copies a Title and returns either an identical or similar
/// array consisting of ASCII that won't make any file system angry
///
/// e.g. POKEPIN R/S to POKEPIN R_S
pub fn escape(title: [12]u8) [12]u8 {
    var result: [12]u8 = title;

    for (result) |*char| {
        if (char.* == '/' or char.* == '\\') char.* = '_';
        if (char.* == 0) break;
    }

    return result;
}

pub const FilePaths = struct {
    rom: []const u8,
    bios: ?[]const u8,
    save: ?[]const u8,
};

pub const io = struct {
    pub const read = struct {
        pub fn todo(comptime log: anytype, comptime format: []const u8, args: anytype) u8 {
            log.debug(format, args);
            return 0;
        }

        pub fn undef(comptime T: type, log: anytype, comptime format: []const u8, args: anytype) ?T {
            log.warn(format, args);
            if (builtin.mode == .Debug and !allow_unhandled_io) std.debug.panic("TODO: Implement I/O Register", .{});

            return null;
        }
    };

    pub const write = struct {
        pub fn undef(log: anytype, comptime format: []const u8, args: anytype) void {
            log.warn(format, args);
            if (builtin.mode == .Debug and !allow_unhandled_io) std.debug.panic("TODO: Implement I/O Register", .{});
        }
    };
};
pub fn readUndefined(log: anytype, comptime format: []const u8, args: anytype) u8 {
    log.warn(format, args);
    if (builtin.mode == .Debug) std.debug.panic("TODO: Implement I/O Register", .{});

    return 0;
}

pub fn writeUndefined(log: anytype, comptime format: []const u8, args: anytype) void {
    log.warn(format, args);
    if (builtin.mode == .Debug) std.debug.panic("TODO: Implement I/O Register", .{});
}

pub const Logger = struct {
    const Self = @This();

    buf: std.io.BufferedWriter(4096 << 2, std.fs.File.Writer),

    pub fn init(file: std.fs.File) Self {
        return .{
            .buf = .{ .unbuffered_writer = file.writer() },
        };
    }

    pub fn print(self: *Self, comptime format: []const u8, args: anytype) !void {
        try self.buf.writer().print(format, args);
    }

    pub fn mgbaLog(self: *Self, cpu: *const Arm7tdmi, opcode: u32) void {
        const fmt_base = "{X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} cpsr: {X:0>8} | ";
        const thumb_fmt = fmt_base ++ "{X:0>4}:\n";
        const arm_fmt = fmt_base ++ "{X:0>8}:\n";

        if (cpu.cpsr.t.read()) {
            if (opcode >> 11 == 0x1E) {
                // Instruction 1 of a BL Opcode, print in ARM mode
                const low = cpu.bus.dbgRead(u16, cpu.r[15]);
                const bl_opcode = @as(u32, opcode) << 16 | low;

                self.print(arm_fmt, Self.fmtArgs(cpu, bl_opcode)) catch @panic("failed to write to log file");
            } else {
                self.print(thumb_fmt, Self.fmtArgs(cpu, opcode)) catch @panic("failed to write to log file");
            }
        } else {
            self.print(arm_fmt, Self.fmtArgs(cpu, opcode)) catch @panic("failed to write to log file");
        }
    }

    fn fmtArgs(cpu: *const Arm7tdmi, opcode: u32) FmtArgTuple {
        return .{
            cpu.r[0],
            cpu.r[1],
            cpu.r[2],
            cpu.r[3],
            cpu.r[4],
            cpu.r[5],
            cpu.r[6],
            cpu.r[7],
            cpu.r[8],
            cpu.r[9],
            cpu.r[10],
            cpu.r[11],
            cpu.r[12],
            cpu.r[13],
            cpu.r[14],
            cpu.r[15],
            cpu.cpsr.raw,
            opcode,
        };
    }
};

const FmtArgTuple = std.meta.Tuple(&.{ u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32 });
