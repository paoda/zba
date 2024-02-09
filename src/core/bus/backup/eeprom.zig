const std = @import("std");

const Allocator = std.mem.Allocator;

const log = std.log.scoped(.Eeprom);

pub const Eeprom = struct {
    const Self = @This();

    addr: u14,

    kind: Kind,
    state: State,
    writer: Writer,
    reader: Reader,

    allocator: Allocator,

    const Kind = enum {
        Unknown,
        Small, // 512B
        Large, // 8KB
    };

    const State = enum {
        Ready,
        Read,
        Write,
        WriteTransfer,
        RequestEnd,
    };

    pub fn read(self: *Self) u1 {
        return self.reader.read();
    }

    pub fn dbgRead(self: *const Self) u1 {
        return self.reader.dbgRead();
    }

    pub fn write(self: *Self, word_count: u16, buf: *[]u8, bit: u1) void {
        if (self.guessKind(word_count)) |found| {
            log.info("EEPROM Kind: {}", .{found});
            self.kind = found;

            // buf.len will not equal zero when a save file was found and loaded.
            // Right now, we assume that the save file is of the correct size which
            // isn't necessarily true, since we can't trust anything a user can influence
            // TODO: use ?[]u8 instead of a 0-sized slice?
            if (buf.len == 0) {
                const len: usize = switch (found) {
                    .Small => 0x200,
                    .Large => 0x2000,
                    else => unreachable,
                };

                buf.* = self.allocator.alloc(u8, len) catch |e| {
                    log.err("Failed to resize EEPROM buf to {} bytes", .{len});
                    std.debug.panic("EEPROM entered irrecoverable state {}", .{e});
                };

                // FIXME: ptr to a slice?
                @memset(buf.*, 0xFF);
            }
        }

        if (self.state == .RequestEnd) {
            // if (bit != 0) log.debug("EEPROM Request did not end in 0u1. TODO: is this ok?", .{});
            self.state = .Ready;
            return;
        }

        switch (self.state) {
            .Ready => self.writer.requestWrite(bit),
            .Read, .Write => self.writer.addressWrite(self.kind, bit),
            .WriteTransfer => self.writer.dataWrite(bit),
            .RequestEnd => unreachable, // We return early just above this block
        }

        self.tick(buf.*);
    }

    pub fn create(allocator: Allocator) Self {
        return .{
            .kind = .Unknown,
            .state = .Ready,
            .writer = Writer.create(),
            .reader = Reader.create(),
            .addr = 0,
            .allocator = allocator,
        };
    }

    fn guessKind(self: *const Self, word_count: u16) ?Kind {
        if (self.kind != .Unknown or self.state != .Read) return null;

        return switch (word_count) {
            17 => .Large,
            9 => .Small,
            else => blk: {
                log.err("Unexpected length of DMA3 Transfer upon initial EEPROM read: {}", .{word_count});
                break :blk null;
            },
        };
    }

    fn tick(self: *Self, buf: []u8) void {
        switch (self.state) {
            .Ready => {
                if (self.writer.len() == 2) {
                    const req: u2 = @intCast(self.writer.finish());
                    switch (req) {
                        0b11 => self.state = .Read,
                        0b10 => self.state = .Write,
                        else => log.err("Unknown EEPROM Request 0b{b:0>2}", .{req}),
                    }
                }
            },
            .Read => {
                switch (self.kind) {
                    .Large => {
                        if (self.writer.len() == 14) {
                            const addr: u10 = @intCast(self.writer.finish());
                            const value = std.mem.readInt(u64, buf[@as(u13, addr) * 8 ..][0..8], .little);

                            self.reader.configure(value);
                            self.state = .RequestEnd;
                        }
                    },
                    .Small => {
                        if (self.writer.len() == 6) {
                            // FIXME: Duplicated code from above
                            const addr: u6 = @intCast(self.writer.finish());
                            const value = std.mem.readInt(u64, buf[@as(u13, addr) * 8 ..][0..8], .little);

                            self.reader.configure(value);
                            self.state = .RequestEnd;
                        }
                    },
                    else => log.err("Unable to calculate EEPROM read address. EEPROM size UNKNOWN", .{}),
                }
            },
            .Write => {
                switch (self.kind) {
                    .Large => {
                        if (self.writer.len() == 14) {
                            self.addr = @as(u10, @intCast(self.writer.finish()));
                            self.state = .WriteTransfer;
                        }
                    },
                    .Small => {
                        if (self.writer.len() == 6) {
                            self.addr = @as(u6, @intCast(self.writer.finish()));
                            self.state = .WriteTransfer;
                        }
                    },
                    else => log.err("Unable to calculate EEPROM write address. EEPROM size UNKNOWN", .{}),
                }
            },
            .WriteTransfer => {
                if (self.writer.len() == 64) {
                    std.mem.writeInt(u64, buf[self.addr * 8 ..][0..8], self.writer.finish(), .little);
                    self.state = .RequestEnd;
                }
            },
            .RequestEnd => unreachable, // We return early in write() if state is .RequestEnd
        }
    }
};

const Reader = struct {
    const Self = @This();

    data: u64,
    i: u8,
    enabled: bool,

    fn create() Self {
        return .{
            .data = 0,
            .i = 0,
            .enabled = false,
        };
    }

    fn read(self: *Self) u1 {
        if (!self.enabled) return 1;

        const bit: u1 = if (self.i < 4) 0 else blk: {
            const idx: u6 = @intCast(63 - (self.i - 4));
            break :blk @truncate(self.data >> idx);
        };

        self.i = (self.i + 1) % (64 + 4);
        if (self.i == 0) self.enabled = false;

        return bit;
    }

    fn dbgRead(self: *const Self) u1 {
        if (!self.enabled) return 1;

        const bit: u1 = if (self.i < 4) blk: {
            break :blk 0;
        } else blk: {
            const idx: u6 = @intCast(63 - (self.i - 4));
            break :blk @truncate(self.data >> idx);
        };

        return bit;
    }

    fn configure(self: *Self, value: u64) void {
        self.data = value;
        self.i = 0;
        self.enabled = true;
    }
};

const Writer = struct {
    const Self = @This();

    data: u64,
    i: u8,

    fn create() Self {
        return .{ .data = 0, .i = 0 };
    }

    fn requestWrite(self: *Self, bit: u1) void {
        const idx: u1 = @intCast(1 - self.i);
        self.data = (self.data & ~(@as(u64, 1) << idx)) | (@as(u64, bit) << idx);
        self.i += 1;
    }

    fn addressWrite(self: *Self, kind: Eeprom.Kind, bit: u1) void {
        if (kind == .Unknown) return;

        const size: u4 = switch (kind) {
            .Large => 13,
            .Small => 5,
            .Unknown => unreachable,
        };

        const idx: u4 = @intCast(size - self.i);
        self.data = (self.data & ~(@as(u64, 1) << idx)) | (@as(u64, bit) << idx);
        self.i += 1;
    }

    fn dataWrite(self: *Self, bit: u1) void {
        const idx: u6 = @intCast(63 - self.i);
        self.data = (self.data & ~(@as(u64, 1) << idx)) | (@as(u64, bit) << idx);
        self.i += 1;
    }

    fn len(self: *const Self) u8 {
        return self.i;
    }

    fn finish(self: *Self) u64 {
        defer self.reset();
        return self.data;
    }

    fn reset(self: *Self) void {
        self.i = 0;
        self.data = 0;
    }
};
