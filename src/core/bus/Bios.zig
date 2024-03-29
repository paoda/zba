const std = @import("std");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Bios);

const rotr = @import("zba-util").rotr;
const forceAlign = @import("../Bus.zig").forceAlign;

/// Size of the BIOS in bytes
pub const size = 0x4000;
const Self = @This();

buf: ?[]u8,
allocator: Allocator,

addr_latch: u32 = 0,

// https://github.com/ITotalJustice/notorious_beeg/issues/106
pub fn read(self: *Self, comptime T: type, r15: u32, address: u32) T {
    if (r15 < Self.size) {
        const addr = forceAlign(T, address);

        self.addr_latch = addr;
        return self._read(T, addr);
    }

    log.warn("Open Bus! Read from 0x{X:0>8}, but PC was 0x{X:0>8}", .{ address, r15 });
    const value = self._read(u32, self.addr_latch);

    return @truncate(rotr(u32, value, 8 * rotateBy(T, address)));
}

fn rotateBy(comptime T: type, address: u32) u32 {
    return switch (T) {
        u8 => address & 3,
        u16 => address & 2,
        u32 => 0,
        else => @compileError("bios: unsupported read width"),
    };
}

pub fn dbgRead(self: *const Self, comptime T: type, r15: u32, address: u32) T {
    if (r15 < Self.size) return self._read(T, forceAlign(T, address));

    const value = self._read(u32, self.addr_latch);
    return @truncate(rotr(u32, value, 8 * rotateBy(T, address)));
}

/// Read without the GBA safety checks
fn _read(self: *const Self, comptime T: type, addr: u32) T {
    const buf = self.buf orelse std.debug.panic("[BIOS] ZBA tried to read {} from 0x{X:0>8} but not BIOS was present", .{ T, addr });

    return switch (T) {
        u32, u16, u8 => std.mem.readInt(T, buf[addr..][0..@sizeOf(T)], .little),
        else => @compileError("BIOS: Unsupported read width"),
    };
}

pub fn write(_: *Self, comptime T: type, addr: u32, value: T) void {
    @setCold(true);
    log.debug("Tried to write {} 0x{X:} to 0x{X:0>8} ", .{ T, value, addr });
}

pub fn init(allocator: Allocator, maybe_path: ?[]const u8) !Self {
    if (maybe_path == null) return .{ .buf = null, .allocator = allocator };
    const file_path = maybe_path.?;

    const buf = try allocator.alloc(u8, Self.size);
    errdefer allocator.free(buf);

    var self: Self = .{ .buf = buf, .allocator = allocator };
    try self.load(file_path);

    return self;
}

pub fn load(self: *Self, file_path: []const u8) !void {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const len = try file.readAll(self.buf orelse return error.UnallocatedBuffer);
    if (len != Self.size) log.err("Expected BIOS to be {}B, was {}B", .{ Self.size, len });
}

pub fn reset(self: *Self) void {
    self.addr_latch = 0;
}

pub fn deinit(self: *Self) void {
    if (self.buf) |buf| self.allocator.free(buf);
    self.* = undefined;
}
