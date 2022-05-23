const std = @import("std");
const Log2Int = std.math.Log2Int;

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

    // TODO: Rename
    pub fn completeFrame(self: *Self) void {
        _ = self.count.fetchAdd(1, .Monotonic);
    }

    pub fn value(self: *Self) u32 {
        const expected = @intToFloat(f64, std.time.ns_per_s);
        const actual = @intToFloat(f64, self.timer.read());

        if (actual >= expected) {
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
pub fn asString(title: [12]u8) []const u8 {
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
