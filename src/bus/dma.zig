const std = @import("std");

const DmaControl = @import("io.zig").DmaControl;
const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;

const readUndefined = @import("../util.zig").readUndefined;
const writeUndefined = @import("../util.zig").writeUndefined;
pub const DmaTuple = std.meta.Tuple(&[_]type{ DmaController(0), DmaController(1), DmaController(2), DmaController(3) });
const log = std.log.scoped(.DmaTransfer);

pub fn create() DmaTuple {
    return .{ DmaController(0).init(), DmaController(1).init(), DmaController(2).init(), DmaController(3).init() };
}

pub fn read(comptime T: type, dma: *const DmaTuple, addr: u32) T {
    const byte = @truncate(u8, addr);

    return switch (T) {
        u32 => switch (byte) {
            0xB8 => @as(T, dma.*[0].cnt.raw) << 16,
            0xC4 => @as(T, dma.*[1].cnt.raw) << 16,
            0xD0 => @as(T, dma.*[2].cnt.raw) << 16,
            0xDC => @as(T, dma.*[3].cnt.raw) << 16,
            else => readUndefined(log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        },
        u16 => switch (byte) {
            0xBA => dma.*[0].cnt.raw,
            0xC6 => dma.*[1].cnt.raw,
            0xD2 => dma.*[2].cnt.raw,
            0xDE => dma.*[3].cnt.raw,
            else => readUndefined(log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        },
        u8 => readUndefined(log, "Tried to perform a {} read to 0x{X:0>8}", .{ T, addr }),
        else => @compileError("DMA: Unsupported read width"),
    };
}

pub fn write(comptime T: type, dma: *DmaTuple, addr: u32, value: T) void {
    const byte = @truncate(u8, addr);

    switch (T) {
        u32 => switch (byte) {
            0xB0 => dma.*[0].setSad(value),
            0xB4 => dma.*[0].setDad(value),
            0xB8 => dma.*[0].setCnt(value),
            0xBC => dma.*[1].setSad(value),
            0xC0 => dma.*[1].setDad(value),
            0xC4 => dma.*[1].setCnt(value),
            0xC8 => dma.*[2].setSad(value),
            0xCC => dma.*[2].setDad(value),
            0xD0 => dma.*[2].setCnt(value),
            0xD4 => dma.*[3].setSad(value),
            0xD8 => dma.*[3].setDad(value),
            0xDC => dma.*[3].setCnt(value),
            else => writeUndefined(log, "Tried to write 0x{X:0>8}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u16 => switch (byte) {
            0xB0 => dma.*[0].setSad(setU32L(dma.*[0].sad, value)),
            0xB2 => dma.*[0].setSad(setU32H(dma.*[0].sad, value)),
            0xB4 => dma.*[0].setDad(setU32L(dma.*[0].dad, value)),
            0xB6 => dma.*[0].setDad(setU32H(dma.*[0].dad, value)),
            0xB8 => dma.*[0].setCntL(value),
            0xBA => dma.*[0].setCntH(value),

            0xBC => dma.*[1].setSad(setU32L(dma.*[1].sad, value)),
            0xBE => dma.*[1].setSad(setU32H(dma.*[1].sad, value)),
            0xC0 => dma.*[1].setDad(setU32L(dma.*[1].dad, value)),
            0xC2 => dma.*[1].setDad(setU32H(dma.*[1].dad, value)),
            0xC4 => dma.*[1].setCntL(value),
            0xC6 => dma.*[1].setCntH(value),

            0xC8 => dma.*[2].setSad(setU32L(dma.*[2].sad, value)),
            0xCA => dma.*[2].setSad(setU32H(dma.*[2].sad, value)),
            0xCC => dma.*[2].setDad(setU32L(dma.*[2].dad, value)),
            0xCE => dma.*[2].setDad(setU32H(dma.*[2].dad, value)),
            0xD0 => dma.*[2].setCntL(value),
            0xD2 => dma.*[2].setCntH(value),

            0xD4 => dma.*[3].setSad(setU32L(dma.*[3].sad, value)),
            0xD6 => dma.*[3].setSad(setU32H(dma.*[3].sad, value)),
            0xD8 => dma.*[3].setDad(setU32L(dma.*[3].dad, value)),
            0xDA => dma.*[3].setDad(setU32H(dma.*[3].dad, value)),
            0xDC => dma.*[3].setCntL(value),
            0xDE => dma.*[3].setCntH(value),
            else => writeUndefined(log, "Tried to write 0x{X:0>4}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u8 => writeUndefined(log, "Tried to write 0x{X:0>2}{} to 0x{X:0>8}", .{ value, T, addr }),
        else => @compileError("DMA: Unsupported write width"),
    }
}

/// Function that creates a DMAController. Determines unique DMA Controller behaiour at compile-time
fn DmaController(comptime id: u2) type {
    return struct {
        const Self = @This();

        const sad_mask: u32 = if (id == 0) 0x07FF_FFFF else 0x0FFF_FFFF;
        const dad_mask: u32 = if (id != 3) 0x07FF_FFFF else 0x0FFF_FFFF;

        /// Write-only. The first address in a DMA transfer. (DMASAD)
        /// Note: use writeSrc instead of manipulating src_addr directly
        sad: u32,
        /// Write-only. The final address in a DMA transffer. (DMADAD)
        /// Note: Use writeDst instead of manipulatig dst_addr directly
        dad: u32,
        /// Write-only. The Word Count for the DMA Transfer (DMACNT_L)
        word_count: if (id == 3) u16 else u14,
        /// Read / Write. DMACNT_H
        /// Note: Use writeControl instead of manipulating cnt directly.
        cnt: DmaControl,

        /// Internal. Currrent Source Address
        _sad: u32,
        /// Internal. Current Destination Address
        _dad: u32,
        /// Internal. Word Count
        _word_count: if (id == 3) u16 else u14,

        // Internal. FIFO Word Count
        _fifo_word_count: u8,

        /// Some DMA Transfers are enabled during Hblank / VBlank and / or
        /// have delays. Thefore bit 15 of DMACNT isn't actually something
        /// we can use to control when we do or do not execute a step in a DMA Transfer
        in_progress: bool,

        pub fn init() Self {
            return .{
                .sad = 0,
                .dad = 0,
                .word_count = 0,
                .cnt = .{ .raw = 0x000 },

                // Internals
                ._sad = 0,
                ._dad = 0,
                ._word_count = 0,
                ._fifo_word_count = 4,
                .in_progress = false,
            };
        }

        pub fn setSad(self: *Self, addr: u32) void {
            self.sad = addr & sad_mask;
        }

        pub fn setDad(self: *Self, addr: u32) void {
            self.dad = addr & dad_mask;
        }

        pub fn setCntL(self: *Self, halfword: u16) void {
            self.word_count = @truncate(@TypeOf(self.word_count), halfword);
        }

        pub fn setCntH(self: *Self, halfword: u16) void {
            const new = DmaControl{ .raw = halfword };

            if (!self.cnt.enabled.read() and new.enabled.read()) {
                // Reload Internals on Rising Edge.
                self._sad = self.sad;
                self._dad = self.dad;
                self._word_count = if (self.word_count == 0) std.math.maxInt(@TypeOf(self._word_count)) else self.word_count;

                // Only a Start Timing of 00 has a DMA Transfer immediately begin
                self.in_progress = new.start_timing.read() == 0b00;
            }

            self.cnt.raw = halfword;
        }

        pub fn setCnt(self: *Self, word: u32) void {
            self.setCntL(@truncate(u16, word));
            self.setCntH(@truncate(u16, word >> 16));
        }

        pub fn step(self: *Self, cpu: *Arm7tdmi) void {
            const is_fifo = (id == 1 or id == 2) and self.cnt.start_timing.read() == 0b11;
            const sad_adj = Self.adjustment(self.cnt.sad_adj.read());
            const dad_adj = if (is_fifo) .Fixed else Self.adjustment(self.cnt.dad_adj.read());

            const transfer_type = is_fifo or self.cnt.transfer_type.read();
            const offset: u32 = if (transfer_type) @sizeOf(u32) else @sizeOf(u16);

            if (transfer_type) {
                cpu.bus.write(u32, self._dad, cpu.bus.read(u32, self._sad));
            } else {
                cpu.bus.write(u16, self._dad, cpu.bus.read(u16, self._sad));
            }

            switch (sad_adj) {
                .Increment => self._sad +%= offset,
                .Decrement => self._sad -%= offset,
                // TODO: Is just ignoring this ok?
                .IncrementReload => log.err("{} is a prohibited adjustment on SAD", .{sad_adj}),
                .Fixed => {},
            }

            switch (dad_adj) {
                .Increment, .IncrementReload => self._dad +%= offset,
                .Decrement => self._dad -%= offset,
                .Fixed => {},
            }

            self._word_count -= 1;

            if (self._word_count == 0) {
                if (!self.cnt.repeat.read()) {
                    // If we're not repeating, Fire the IRQs and disable the DMA
                    if (self.cnt.irq.read()) {
                        switch (id) {
                            0 => cpu.bus.io.irq.dma0.set(),
                            1 => cpu.bus.io.irq.dma0.set(),
                            2 => cpu.bus.io.irq.dma0.set(),
                            3 => cpu.bus.io.irq.dma0.set(),
                        }

                        cpu.handleInterrupt();
                    }

                    self.cnt.enabled.unset();
                }

                // We want to disable our internal enabled flag regardless of repeat
                // because we only want to step A DMA that repeats during it's specific
                // timing window
                self.in_progress = false;
            }
        }

        pub fn pollBlankingDma(self: *Self, comptime kind: DmaKind) void {
            if (self.in_progress) return;

            switch (kind) {
                .HBlank => self.in_progress = self.cnt.enabled.read() and self.cnt.start_timing.read() == 0b10,
                .VBlank => self.in_progress = self.cnt.enabled.read() and self.cnt.start_timing.read() == 0b01,
                .Immediate, .Special => {},
            }

            if (self.cnt.repeat.read() and self.in_progress) {
                self._word_count = if (self.word_count == 0) std.math.maxInt(@TypeOf(self._word_count)) else self.word_count;
                if (Self.adjustment(self.cnt.dad_adj.read()) == .IncrementReload) self._dad = self.dad;
            }
        }

        pub fn requestSoundDma(self: *Self, fifo_addr: u32) void {
            comptime std.debug.assert(id == 1 or id == 2);

            const is_enabled = self.cnt.enabled.read();
            const is_special = self.cnt.start_timing.read() == 0b11;
            const is_repeating = self.cnt.repeat.read();
            const is_fifo = self.dad == fifo_addr;

            if (is_enabled and is_special and is_repeating and is_fifo) {
                self._word_count = 4;
                self.cnt.transfer_type.set();
                self.in_progress = true;
            }
        }

        fn adjustment(idx: u2) Adjustment {
            return std.meta.intToEnum(Adjustment, idx) catch unreachable;
        }
    };
}

pub fn pollBlankingDma(bus: *Bus, comptime kind: DmaKind) void {
    bus.dma[0].pollBlankingDma(kind);
    bus.dma[1].pollBlankingDma(kind);
    bus.dma[2].pollBlankingDma(kind);
    bus.dma[3].pollBlankingDma(kind);
}

const Adjustment = enum(u2) {
    Increment = 0,
    Decrement = 1,
    Fixed = 2,
    IncrementReload = 3,
};

const DmaKind = enum(u2) {
    Immediate = 0,
    HBlank,
    VBlank,
    Special,
};

fn setU32L(left: u32, right: u16) u32 {
    return (left & 0xFFFF_0000) | right;
}

fn setU32H(left: u32, right: u16) u32 {
    return (left & 0x0000_FFFF) | (@as(u32, right) << 16);
}
