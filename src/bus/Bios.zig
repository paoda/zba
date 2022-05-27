const std = @import("std");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Bios);

/// Size of the BIOS in bytes
pub const size = 0x4000;
const Self = @This();

buf: ?[]u8,
alloc: Allocator,

addr_latch: u32,

pub fn init(alloc: Allocator, maybe_path: ?[]const u8) !Self {
    var buf: ?[]u8 = null;
    if (maybe_path) |path| {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        buf = try file.readToEndAlloc(alloc, try file.getEndPos());
    }

    return Self{
        .buf = buf,
        .alloc = alloc,
        .addr_latch = 0,
    };
}

pub fn deinit(self: Self) void {
    if (self.buf) |buf| self.alloc.free(buf);
}

pub fn checkedRead(self: *Self, comptime T: type, r15: u32, addr: u32) T {
    if (r15 < Self.size) {
        // FIXME: Just give up on *const Self on bus reads, Rekai
        self.addr_latch = addr;

        return self.read(T, addr);
    }

    log.debug("Rejected read since r15=0x{X:0>8}", .{r15});
    return @truncate(T, self.read(T, self.addr_latch + 8));
}

fn read(self: *const Self, comptime T: type, addr: u32) T {
    if (self.buf) |buf| {
        return switch (T) {
            u32 => (@as(u32, buf[addr + 3]) << 24) | (@as(u32, buf[addr + 2]) << 16) | (@as(u32, buf[addr + 1]) << 8) | (@as(u32, buf[addr])),
            u16 => (@as(u16, buf[addr + 1]) << 8) | @as(u16, buf[addr]),
            u8 => buf[addr],
            else => @compileError("BIOS: Unsupported read width"),
        };
    }

    std.debug.panic("[BIOS] ZBA tried to read {} from 0x{X:0>8} but not BIOS was present", .{ T, addr });
}

pub fn write(_: *Self, comptime T: type, addr: u32, value: T) void {
    @setCold(true);
    log.debug("Tried to write {} 0x{X:} to 0x{X:0>8} ", .{ T, value, addr });
}
