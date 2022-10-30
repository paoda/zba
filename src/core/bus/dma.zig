const std = @import("std");
const util = @import("../../util.zig");

const DmaControl = @import("io.zig").DmaControl;
const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;

pub const DmaTuple = std.meta.Tuple(&[_]type{ DmaController(0), DmaController(1), DmaController(2), DmaController(3) });
const log = std.log.scoped(.DmaTransfer);

const getHalf = util.getHalf;
const setHalf = util.setHalf;
const setQuart = util.setQuart;

const rotr = @import("../../util.zig").rotr;

pub fn create() DmaTuple {
    return .{ DmaController(0).init(), DmaController(1).init(), DmaController(2).init(), DmaController(3).init() };
}

pub fn read(comptime T: type, dma: *const DmaTuple, addr: u32) ?T {
    const byte_addr = @truncate(u8, addr);

    return switch (T) {
        u32 => switch (byte_addr) {
            0xB0, 0xB4 => null, // DMA0SAD, DMA0DAD,
            0xB8 => @as(T, dma.*[0].dmacntH()) << 16, // DMA0CNT_L is write-only
            0xBC, 0xC0 => null, // DMA1SAD, DMA1DAD
            0xC4 => @as(T, dma.*[1].dmacntH()) << 16, // DMA1CNT_L is write-only
            0xC8, 0xCC => null, // DMA2SAD, DMA2DAD
            0xD0 => @as(T, dma.*[2].dmacntH()) << 16, // DMA2CNT_L is write-only
            0xD4, 0xD8 => null, // DMA3SAD, DMA3DAD
            0xDC => @as(T, dma.*[3].dmacntH()) << 16, // DMA3CNT_L is write-only
            else => util.io.read.err(T, log, "unaligned {} read from 0x{X:0>8}", .{ T, addr }),
        },
        u16 => switch (byte_addr) {
            0xB0, 0xB2, 0xB4, 0xB6 => null, // DMA0SAD, DMA0DAD
            0xB8 => 0x0000, // DMA0CNT_L, suite.gba expects 0x0000 instead of 0xDEAD
            0xBA => dma.*[0].dmacntH(),

            0xBC, 0xBE, 0xC0, 0xC2 => null, // DMA1SAD, DMA1DAD
            0xC4 => 0x0000, // DMA1CNT_L
            0xC6 => dma.*[1].dmacntH(),

            0xC8, 0xCA, 0xCC, 0xCE => null, // DMA2SAD, DMA2DAD
            0xD0 => 0x0000, // DMA2CNT_L
            0xD2 => dma.*[2].dmacntH(),

            0xD4, 0xD6, 0xD8, 0xDA => null, // DMA3SAD, DMA3DAD
            0xDC => 0x0000, // DMA3CNT_L
            0xDE => dma.*[3].dmacntH(),
            else => util.io.read.err(T, log, "unaligned {} read from 0x{X:0>8}", .{ T, addr }),
        },
        u8 => switch (byte_addr) {
            0xB0...0xB7 => null, // DMA0SAD, DMA0DAD
            0xB8, 0xB9 => 0x00, // DMA0CNT_L
            0xBA, 0xBB => @truncate(T, dma.*[0].dmacntH() >> getHalf(byte_addr)),

            0xBC...0xC3 => null, // DMA1SAD, DMA1DAD
            0xC4, 0xC5 => 0x00, // DMA1CNT_L
            0xC6, 0xC7 => @truncate(T, dma.*[1].dmacntH() >> getHalf(byte_addr)),

            0xC8...0xCF => null, // DMA2SAD, DMA2DAD
            0xD0, 0xD1 => 0x00, // DMA2CNT_L
            0xD2, 0xD3 => @truncate(T, dma.*[2].dmacntH() >> getHalf(byte_addr)),

            0xD4...0xDB => null, // DMA3SAD, DMA3DAD
            0xDC, 0xDD => 0x00, // DMA3CNT_L
            0xDE, 0xDF => @truncate(T, dma.*[3].dmacntH() >> getHalf(byte_addr)),
            else => util.io.read.err(T, log, "unexpected {} read from 0x{X:0>8}", .{ T, addr }),
        },
        else => @compileError("DMA: Unsupported read width"),
    };
}

pub fn write(comptime T: type, dma: *DmaTuple, addr: u32, value: T) void {
    const byte_addr = @truncate(u8, addr);

    switch (T) {
        u32 => switch (byte_addr) {
            0xB0 => dma.*[0].setDmasad(value),
            0xB4 => dma.*[0].setDmadad(value),
            0xB8 => dma.*[0].setDmacnt(value),

            0xBC => dma.*[1].setDmasad(value),
            0xC0 => dma.*[1].setDmadad(value),
            0xC4 => dma.*[1].setDmacnt(value),

            0xC8 => dma.*[2].setDmasad(value),
            0xCC => dma.*[2].setDmadad(value),
            0xD0 => dma.*[2].setDmacnt(value),

            0xD4 => dma.*[3].setDmasad(value),
            0xD8 => dma.*[3].setDmadad(value),
            0xDC => dma.*[3].setDmacnt(value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>8}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u16 => switch (byte_addr) {
            0xB0, 0xB2 => dma.*[0].setDmasad(setHalf(u32, dma.*[0].sad, byte_addr, value)),
            0xB4, 0xB6 => dma.*[0].setDmadad(setHalf(u32, dma.*[0].dad, byte_addr, value)),
            0xB8 => dma.*[0].setDmacntL(value),
            0xBA => dma.*[0].setDmacntH(value),

            0xBC, 0xBE => dma.*[1].setDmasad(setHalf(u32, dma.*[1].sad, byte_addr, value)),
            0xC0, 0xC2 => dma.*[1].setDmadad(setHalf(u32, dma.*[1].dad, byte_addr, value)),
            0xC4 => dma.*[1].setDmacntL(value),
            0xC6 => dma.*[1].setDmacntH(value),

            0xC8, 0xCA => dma.*[2].setDmasad(setHalf(u32, dma.*[2].sad, byte_addr, value)),
            0xCC, 0xCE => dma.*[2].setDmadad(setHalf(u32, dma.*[2].dad, byte_addr, value)),
            0xD0 => dma.*[2].setDmacntL(value),
            0xD2 => dma.*[2].setDmacntH(value),

            0xD4, 0xD6 => dma.*[3].setDmasad(setHalf(u32, dma.*[3].sad, byte_addr, value)),
            0xD8, 0xDA => dma.*[3].setDmadad(setHalf(u32, dma.*[3].dad, byte_addr, value)),
            0xDC => dma.*[3].setDmacntL(value),
            0xDE => dma.*[3].setDmacntH(value),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>4}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        u8 => switch (byte_addr) {
            0xB0, 0xB1, 0xB2, 0xB3 => dma.*[0].setDmasad(setQuart(dma.*[0].sad, byte_addr, value)),
            0xB4, 0xB5, 0xB6, 0xB7 => dma.*[0].setDmadad(setQuart(dma.*[0].dad, byte_addr, value)),
            0xB8, 0xB9 => dma.*[0].setDmacntL(setHalf(u16, dma.*[0].word_count, byte_addr, value)),
            0xBA, 0xBB => dma.*[0].setDmacntH(setHalf(u16, dma.*[0].cnt.raw, byte_addr, value)),

            0xBC, 0xBD, 0xBE, 0xBF => dma.*[1].setDmasad(setQuart(dma.*[1].sad, byte_addr, value)),
            0xC0, 0xC1, 0xC2, 0xC3 => dma.*[1].setDmadad(setQuart(dma.*[1].dad, byte_addr, value)),
            0xC4, 0xC5 => dma.*[1].setDmacntL(setHalf(u16, dma.*[1].word_count, byte_addr, value)),
            0xC6, 0xC7 => dma.*[1].setDmacntH(setHalf(u16, dma.*[1].cnt.raw, byte_addr, value)),

            0xC8, 0xC9, 0xCA, 0xCB => dma.*[2].setDmasad(setQuart(dma.*[2].sad, byte_addr, value)),
            0xCC, 0xCD, 0xCE, 0xCF => dma.*[2].setDmadad(setQuart(dma.*[2].dad, byte_addr, value)),
            0xD0, 0xD1 => dma.*[2].setDmacntL(setHalf(u16, dma.*[2].word_count, byte_addr, value)),
            0xD2, 0xD3 => dma.*[2].setDmacntH(setHalf(u16, dma.*[2].cnt.raw, byte_addr, value)),

            0xD4, 0xD5, 0xD6, 0xD7 => dma.*[3].setDmasad(setQuart(dma.*[3].sad, byte_addr, value)),
            0xD8, 0xD9, 0xDA, 0xDB => dma.*[3].setDmadad(setQuart(dma.*[3].dad, byte_addr, value)),
            0xDC, 0xDD => dma.*[3].setDmacntL(setHalf(u16, dma.*[3].word_count, byte_addr, value)),
            0xDE, 0xDF => dma.*[3].setDmacntH(setHalf(u16, dma.*[3].cnt.raw, byte_addr, value)),
            else => util.io.write.undef(log, "Tried to write 0x{X:0>2}{} to 0x{X:0>8}", .{ value, T, addr }),
        },
        else => @compileError("DMA: Unsupported write width"),
    }
}

/// Function that creates a DMAController. Determines unique DMA Controller behaiour at compile-time
fn DmaController(comptime id: u2) type {
    return struct {
        const Self = @This();

        const sad_mask: u32 = if (id == 0) 0x07FF_FFFF else 0x0FFF_FFFF;
        const dad_mask: u32 = if (id != 3) 0x07FF_FFFF else 0x0FFF_FFFF;
        const WordCount = if (id == 3) u16 else u14;

        /// Write-only. The first address in a DMA transfer. (DMASAD)
        /// Note: use writeSrc instead of manipulating src_addr directly
        sad: u32,
        /// Write-only. The final address in a DMA transffer. (DMADAD)
        /// Note: Use writeDst instead of manipulatig dst_addr directly
        dad: u32,
        /// Write-only. The Word Count for the DMA Transfer (DMACNT_L)
        word_count: WordCount,
        /// Read / Write. DMACNT_H
        /// Note: Use writeControl instead of manipulating cnt directly.
        cnt: DmaControl,

        /// Internal. The last successfully read value
        data_latch: u32,
        /// Internal. Currrent Source Address
        sad_latch: u32,
        /// Internal. Current Destination Address
        dad_latch: u32,
        /// Internal. Word Count
        _word_count: WordCount,

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
                .sad_latch = 0,
                .dad_latch = 0,
                .data_latch = 0,

                ._word_count = 0,
                .in_progress = false,
            };
        }

        pub fn setDmasad(self: *Self, addr: u32) void {
            self.sad = addr & sad_mask;
        }

        pub fn setDmadad(self: *Self, addr: u32) void {
            self.dad = addr & dad_mask;
        }

        pub fn setDmacntL(self: *Self, halfword: u16) void {
            self.word_count = @truncate(@TypeOf(self.word_count), halfword);
        }

        pub fn dmacntH(self: *const Self) u16 {
            return self.cnt.raw & if (id == 3) 0xFFE0 else 0xF7E0;
        }

        pub fn setDmacntH(self: *Self, halfword: u16) void {
            const new = DmaControl{ .raw = halfword };

            if (!self.cnt.enabled.read() and new.enabled.read()) {
                // Reload Internals on Rising Edge.
                self.sad_latch = self.sad;
                self.dad_latch = self.dad;
                self._word_count = if (self.word_count == 0) std.math.maxInt(WordCount) else self.word_count;

                // Only a Start Timing of 00 has a DMA Transfer immediately begin
                self.in_progress = new.start_timing.read() == 0b00;
            }

            self.cnt.raw = halfword;
        }

        pub fn setDmacnt(self: *Self, word: u32) void {
            self.setDmacntL(@truncate(u16, word));
            self.setDmacntH(@truncate(u16, word >> 16));
        }

        pub fn step(self: *Self, cpu: *Arm7tdmi) void {
            const is_fifo = (id == 1 or id == 2) and self.cnt.start_timing.read() == 0b11;
            const sad_adj = @intToEnum(Adjustment, self.cnt.sad_adj.read());
            const dad_adj = if (is_fifo) .Fixed else @intToEnum(Adjustment, self.cnt.dad_adj.read());

            const transfer_type = is_fifo or self.cnt.transfer_type.read();
            const offset: u32 = if (transfer_type) @sizeOf(u32) else @sizeOf(u16);

            const mask = if (transfer_type) ~@as(u32, 3) else ~@as(u32, 1);
            const sad_addr = self.sad_latch & mask;
            const dad_addr = self.dad_latch & mask;

            if (transfer_type) {
                if (sad_addr >= 0x0200_0000) self.data_latch = cpu.bus.read(u32, sad_addr);
                cpu.bus.write(u32, dad_addr, self.data_latch);
            } else {
                if (sad_addr >= 0x0200_0000) {
                    const value: u32 = cpu.bus.read(u16, sad_addr);
                    self.data_latch = value << 16 | value;
                }

                cpu.bus.write(u16, dad_addr, @truncate(u16, rotr(u32, self.data_latch, 8 * (dad_addr & 3))));
            }

            switch (sad_adj) {
                .Increment => self.sad_latch +%= offset,
                .Decrement => self.sad_latch -%= offset,
                // FIXME: Is just ignoring this ok?
                .IncrementReload => log.err("{} is a prohibited adjustment on SAD", .{sad_adj}),
                .Fixed => {},
            }

            switch (dad_adj) {
                .Increment, .IncrementReload => self.dad_latch +%= offset,
                .Decrement => self.dad_latch -%= offset,
                .Fixed => {},
            }

            self._word_count -= 1;

            if (self._word_count == 0) {
                if (self.cnt.irq.read()) {
                    switch (id) {
                        0 => cpu.bus.io.irq.dma0.set(),
                        1 => cpu.bus.io.irq.dma1.set(),
                        2 => cpu.bus.io.irq.dma2.set(),
                        3 => cpu.bus.io.irq.dma3.set(),
                    }

                    cpu.handleInterrupt();
                }

                // If we're not repeating, Fire the IRQs and disable the DMA
                if (!self.cnt.repeat.read()) self.cnt.enabled.unset();

                // We want to disable our internal enabled flag regardless of repeat
                // because we only want to step A DMA that repeats during it's specific
                // timing window
                self.in_progress = false;
            }
        }

        fn poll(self: *Self, comptime kind: DmaKind) void {
            if (self.in_progress) return; // If there's an ongoing DMA Transfer, exit early

            // No ongoing DMA Transfer, We want to check if we should repeat an existing one
            // Determined by the repeat bit and whether the DMA is in the right start_timing
            switch (kind) {
                .VBlank => self.in_progress = self.cnt.enabled.read() and self.cnt.start_timing.read() == 0b01,
                .HBlank => self.in_progress = self.cnt.enabled.read() and self.cnt.start_timing.read() == 0b10,
                .Immediate, .Special => {},
            }

            // If we determined that the repeat bit is set (and now the Hblank / Vblank DMA is now in progress)
            // Reload internal word count latch
            // Reload internal DAD latch if we are in IncrementRelaod
            if (self.in_progress) {
                self._word_count = if (self.word_count == 0) std.math.maxInt(@TypeOf(self._word_count)) else self.word_count;
                if (@intToEnum(Adjustment, self.cnt.dad_adj.read()) == .IncrementReload) self.dad_latch = self.dad;
            }
        }

        pub fn requestAudio(self: *Self, _: u32) void {
            comptime std.debug.assert(id == 1 or id == 2);
            if (self.in_progress) return; // APU must wait their turn

            // DMA May not be configured for handling DMAs
            if (self.cnt.start_timing.read() != 0b11) return;

            // We Assume the Repeat Bit is Set
            // We Assume that DAD is set to 0x0400_00A0 or 0x0400_00A4 (fifo_addr)
            // We Assume DMACNT_L is set to 4

            // FIXME: Safe to just assume whatever DAD is set to is the FIFO Address?
            // self.dad_latch = fifo_addr;
            self.cnt.repeat.set();
            self._word_count = 4;
            self.in_progress = true;
        }
    };
}

pub fn pollDmaOnBlank(bus: *Bus, comptime kind: DmaKind) void {
    bus.dma[0].poll(kind);
    bus.dma[1].poll(kind);
    bus.dma[2].poll(kind);
    bus.dma[3].poll(kind);
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
