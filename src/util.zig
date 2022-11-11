const std = @import("std");
const builtin = @import("builtin");
const config = @import("config.zig");

const Log2Int = std.math.Log2Int;
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;

// Sign-Extend value of type `T` to type `U`
pub fn sext(comptime T: type, comptime U: type, value: T) T {
    // U must have less bits than T
    comptime std.debug.assert(@typeInfo(U).Int.bits <= @typeInfo(T).Int.bits);

    const iT = std.meta.Int(.signed, @typeInfo(T).Int.bits);
    const ExtU = if (@typeInfo(U).Int.signedness == .unsigned) T else iT;
    const shift_amt = @intCast(Log2Int(T), @typeInfo(T).Int.bits - @typeInfo(U).Int.bits);

    return @bitCast(T, @bitCast(iT, @as(ExtU, @truncate(U, value)) << shift_amt) >> shift_amt);
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

/// Creates a copy of a title with all Filesystem-invalid characters replaced
///
/// e.g. POKEPIN R/S to POKEPIN R_S
pub fn escape(title: [12]u8) [12]u8 {
    var ret: [12]u8 = title;

    //TODO: Add more replacements
    std.mem.replaceScalar(u8, &ret, '/', '_');
    std.mem.replaceScalar(u8, &ret, '\\', '_');

    return ret;
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

        pub fn undef(comptime T: type, comptime log: anytype, comptime format: []const u8, args: anytype) ?T {
            @setCold(true);

            const unhandled_io = config.config().debug.unhandled_io;

            log.warn(format, args);
            if (builtin.mode == .Debug and !unhandled_io) std.debug.panic("TODO: Implement I/O Register", .{});

            return null;
        }

        pub fn err(comptime T: type, comptime log: anytype, comptime format: []const u8, args: anytype) ?T {
            @setCold(true);

            log.err(format, args);
            return null;
        }
    };

    pub const write = struct {
        pub fn undef(log: anytype, comptime format: []const u8, args: anytype) void {
            const unhandled_io = config.config().debug.unhandled_io;

            log.warn(format, args);
            if (builtin.mode == .Debug and !unhandled_io) std.debug.panic("TODO: Implement I/O Register", .{});
        }
    };
};

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
        try self.buf.flush(); // FIXME: On panics, whatever is in the buffer isn't written to file
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
            cpu.r[15] - if (cpu.cpsr.t.read()) 2 else @as(u32, 4),
            cpu.cpsr.raw,
            opcode,
        };
    }
};

const FmtArgTuple = std.meta.Tuple(&.{ u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32 });

pub const audio = struct {
    const _io = @import("core/bus/io.zig");

    const ToneSweep = @import("core/apu/ToneSweep.zig");
    const Tone = @import("core/apu/Tone.zig");
    const Wave = @import("core/apu/Wave.zig");
    const Noise = @import("core/apu/Noise.zig");

    pub const length = struct {
        const FrameSequencer = @import("core/apu.zig").FrameSequencer;

        /// Update State of Ch1, Ch2 and Ch3 length timer
        pub fn update(comptime T: type, self: *T, fs: *const FrameSequencer, nrx34: _io.Frequency) void {
            comptime std.debug.assert(T == ToneSweep or T == Tone or T == Wave);

            // Write to NRx4 when FS's next step is not one that clocks the length counter
            if (!fs.isLengthNext()) {
                // If length_enable was disabled but is now enabled and length timer is not 0 already,
                // decrement the length timer

                if (!self.freq.length_enable.read() and nrx34.length_enable.read() and self.len_dev.timer != 0) {
                    self.len_dev.timer -= 1;

                    // If Length Timer is now 0 and trigger is clear, disable the channel
                    if (self.len_dev.timer == 0 and !nrx34.trigger.read()) self.enabled = false;
                }
            }
        }

        pub const ch4 = struct {
            /// update state of ch4 length timer
            pub fn update(self: *Noise, fs: *const FrameSequencer, nr44: _io.NoiseControl) void {
                // Write to NRx4 when FS's next step is not one that clocks the length counter
                if (!fs.isLengthNext()) {
                    // If length_enable was disabled but is now enabled and length timer is not 0 already,
                    // decrement the length timer

                    if (!self.cnt.length_enable.read() and nr44.length_enable.read() and self.len_dev.timer != 0) {
                        self.len_dev.timer -= 1;

                        // If Length Timer is now 0 and trigger is clear, disable the channel
                        if (self.len_dev.timer == 0 and !nr44.trigger.read()) self.enabled = false;
                    }
                }
            }
        };
    };
};

/// Sets a quarter (8) of the bits of the u32 `left` to the value of u8 `right`
pub inline fn setQuart(left: u32, addr: u8, right: u8) u32 {
    const offset = @truncate(u2, addr);

    return switch (offset) {
        0b00 => (left & 0xFFFF_FF00) | right,
        0b01 => (left & 0xFFFF_00FF) | @as(u32, right) << 8,
        0b10 => (left & 0xFF00_FFFF) | @as(u32, right) << 16,
        0b11 => (left & 0x00FF_FFFF) | @as(u32, right) << 24,
    };
}

/// Calculates the correct shift offset for an aligned/unaligned u8 read
///
/// TODO: Support u16 reads of u32 values?
pub inline fn getHalf(byte: u8) u4 {
    return @truncate(u4, byte & 1) << 3;
}

pub inline fn setHalf(comptime T: type, left: T, addr: u8, right: HalfInt(T)) T {
    const offset = @truncate(u1, addr >> if (T == u32) 1 else 0);

    return switch (T) {
        u32 => switch (offset) {
            0b0 => (left & 0xFFFF_0000) | right,
            0b1 => (left & 0x0000_FFFF) | @as(u32, right) << 16,
        },
        u16 => switch (offset) {
            0b0 => (left & 0xFF00) | right,
            0b1 => (left & 0x00FF) | @as(u16, right) << 8,
        },
        else => @compileError("unsupported type"),
    };
}

/// The Integer type which corresponds to T with exactly half the amount of bits
fn HalfInt(comptime T: type) type {
    const type_info = @typeInfo(T);
    comptime std.debug.assert(type_info == .Int); // Type must be an integer
    comptime std.debug.assert(type_info.Int.bits % 2 == 0); // Type must have an even amount of bits

    return std.meta.Int(type_info.Int.signedness, type_info.Int.bits >> 1);
}
