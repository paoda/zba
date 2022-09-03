const std = @import("std");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Bios);

/// Size of the BIOS in bytes
pub const size = 0x4000;
const Self = @This();

buf: ?[]u8,
allocator: Allocator,

addr_latch: u32,

pub fn init(allocator: Allocator, maybe_path: ?[]const u8) !Self {
    const buf: ?[]u8 = if (maybe_path) |path| blk: {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        break :blk try file.readToEndAlloc(allocator, try file.getEndPos());
    } else null;

    return Self{
        .buf = buf,
        .allocator = allocator,
        .addr_latch = 0,
    };
}

pub fn deinit(self: *Self) void {
    if (self.buf) |buf| self.allocator.free(buf);
    self.* = undefined;
}

pub fn read(self: *Self, comptime T: type, r15: u32, addr: u32) T {
    if (r15 < Self.size) {
        self.addr_latch = addr;
        return self.uncheckedRead(T, addr);
    }

    log.debug("Rejected read since r15=0x{X:0>8}", .{r15});
    return @truncate(T, self.uncheckedRead(T, self.addr_latch + 8));
}

pub fn dbgRead(self: *const Self, comptime T: type, r15: u32, addr: u32) T {
    if (r15 < Self.size) return self.uncheckedRead(T, addr);
    return @truncate(T, self.uncheckedRead(T, self.addr_latch + 8));
}

fn uncheckedRead(self: *const Self, comptime T: type, addr: u32) T {
    if (self.buf) |buf| {
        return switch (T) {
            u32, u16, u8 => std.mem.readIntSliceLittle(T, buf[addr..][0..@sizeOf(T)]),
            else => @compileError("BIOS: Unsupported read width"),
        };
    }

    std.debug.panic("[BIOS] ZBA tried to read {} from 0x{X:0>8} but not BIOS was present", .{ T, addr });
}

pub fn write(_: *Self, comptime T: type, addr: u32, value: T) void {
    @setCold(true);
    log.debug("Tried to write {} 0x{X:} to 0x{X:0>8} ", .{ T, value, addr });
}
