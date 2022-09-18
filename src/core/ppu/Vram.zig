const std = @import("std");
const io = @import("../bus/io.zig");

const Allocator = std.mem.Allocator;

const buf_len = 0x18000;
const Self = @This();

buf: []u8,
allocator: Allocator,

pub fn read(self: *const Self, comptime T: type, address: usize) T {
    const addr = Self.mirror(address);

    return switch (T) {
        u32, u16, u8 => std.mem.readIntSliceLittle(T, self.buf[addr..][0..@sizeOf(T)]),
        else => @compileError("VRAM: Unsupported read width"),
    };
}

pub fn write(self: *Self, comptime T: type, dispcnt: io.DisplayControl, address: usize, value: T) void {
    const mode: u3 = dispcnt.bg_mode.read();
    const idx = Self.mirror(address);

    switch (T) {
        u32, u16 => std.mem.writeIntSliceLittle(T, self.buf[idx..][0..@sizeOf(T)], value),
        u8 => {
            // Ignore write if it falls within the boundaries of OBJ VRAM
            switch (mode) {
                0, 1, 2 => if (0x0001_0000 <= idx) return,
                else => if (0x0001_4000 <= idx) return,
            }

            const align_idx = idx & ~@as(u32, 1); // Aligned to a halfword boundary
            std.mem.writeIntSliceLittle(u16, self.buf[align_idx..][0..@sizeOf(u16)], @as(u16, value) * 0x101);
        },
        else => @compileError("VRAM: Unsupported write width"),
    }
}

pub fn init(allocator: Allocator) !Self {
    const buf = try allocator.alloc(u8, buf_len);
    std.mem.set(u8, buf, 0);

    return Self{ .buf = buf, .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.buf);
    self.* = undefined;
}

pub fn mirror(address: usize) usize {
    // Mirrored in steps of 128K (64K + 32K + 32K) (abcc)
    const addr = address & 0x1FFFF;

    // If the address is within 96K we don't do anything,
    // otherwise we want to mirror the last 32K (addresses between 64K and 96K)
    return if (addr < buf_len) addr else 0x10000 + (addr & 0x7FFF);
}
