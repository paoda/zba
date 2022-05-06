const std = @import("std");

const DmaControl = @import("io.zig").DmaControl;
const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;

pub const DmaTuple = std.meta.Tuple(&[_]type{ DmaController(0), DmaController(1), DmaController(2), DmaController(3) });
const log = std.log.scoped(.DmaTransfer);

pub fn create() DmaTuple {
    return .{ DmaController(0).init(), DmaController(1).init(), DmaController(2).init(), DmaController(3).init() };
}

/// Function that creates a DMAController. Determines unique DMA Controller behaiour at compile-time
fn DmaController(comptime id: u2) type {
    return struct {
        const Self = @This();

        const sad_mask: u32 = if (id == 0) 0x07FF_FFFF else 0x0FFF_FFFF;
        const dad_mask: u32 = if (id != 3) 0x07FF_FFFF else 0x0FFF_FFFF;

        /// Determines whether DMAController is for DMA0, DMA1, DMA2 or DMA3
        /// Note: Determined at comptime
        id: u2,
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
        active: bool,

        pub fn init() Self {
            return .{
                .id = id,
                .sad = 0,
                .dad = 0,
                .word_count = 0,
                .cnt = .{ .raw = 0x000 },

                // Internals
                ._sad = 0,
                ._dad = 0,
                ._word_count = 0,
                ._fifo_word_count = 4,
                .active = false,
            };
        }

        pub fn writeSad(self: *Self, addr: u32) void {
            self.sad = addr & sad_mask;
        }

        pub fn writeDad(self: *Self, addr: u32) void {
            self.dad = addr & dad_mask;
        }

        pub fn writeWordCount(self: *Self, halfword: u16) void {
            self.word_count = @truncate(@TypeOf(self.word_count), halfword);
        }

        pub fn writeCntHigh(self: *Self, halfword: u16) void {
            const new = DmaControl{ .raw = halfword };

            if (!self.cnt.enabled.read() and new.enabled.read()) {
                // Reload Internals on Rising Edge.
                self._sad = self.sad;
                self._dad = self.dad;
                self._word_count = if (self.word_count == 0) std.math.maxInt(@TypeOf(self._word_count)) else self.word_count;

                // Only a Start Timing of 00 has a DMA Transfer immediately begin
                self.active = new.start_timing.read() == 0b00;
            }

            self.cnt.raw = halfword;
        }

        pub fn writeCnt(self: *Self, word: u32) void {
            self.word_count = @truncate(@TypeOf(self.word_count), word);
            self.writeCntHigh(@truncate(u16, word >> 16));
        }

        pub fn step(self: *Self, cpu: *Arm7tdmi) bool {
            if (!self.active) return false;

            const sad_adj = std.meta.intToEnum(Adjustment, self.cnt.sad_adj.read()) catch unreachable;
            const dad_adj = std.meta.intToEnum(Adjustment, self.cnt.dad_adj.read()) catch unreachable;
            const is_fifo = (self.id == 1 or self.id == 2) and self.cnt.start_timing.read() == 0b11;

            const transfer_type = self.cnt.transfer_type.read() or is_fifo;
            const offset: u32 = if (transfer_type) @sizeOf(u32) else @sizeOf(u16);

            if (transfer_type) {
                cpu.bus.write(u32, self._dad, cpu.bus.read(u32, self._sad));
            } else {
                cpu.bus.write(u16, self._dad, cpu.bus.read(u16, self._sad));
            }

            switch (sad_adj) {
                .Increment => self._sad +%= offset,
                .Decrement => self._sad -%= offset,
                .Fixed => {},

                // TODO: Figure out correct behaviour on Illegal Source Addr Control Type
                .IncrementReload => std.debug.panic("panic(DmaTransfer): {} is an illegal src addr adjustment type", .{sad_adj}),
            }

            if (!is_fifo) {
                switch (dad_adj) {
                    .Increment, .IncrementReload => self._dad +%= offset,
                    .Decrement => self._dad -%= offset,
                    .Fixed => {},
                }
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
                self.active = false;
            }

            return true;
        }

        pub fn isBlocking(self: *const Self) bool {
            // A DMA Transfer is Blocking if it is Immediate
            return self.cnt.start_timing.read() == 0b00;
        }

        pub fn pollBlankingDma(self: *Self, comptime kind: DmaKind) void {
            if (self.active) return;

            switch (kind) {
                .HBlank => self.active = self.cnt.enabled.read() and self.cnt.start_timing.read() == 0b10,
                .VBlank => self.active = self.cnt.enabled.read() and self.cnt.start_timing.read() == 0b01,
                .Immediate, .Special => {},
            }

            if (self.cnt.repeat.read() and self.active) {
                self._word_count = if (self.word_count == 0) std.math.maxInt(@TypeOf(self._word_count)) else self.word_count;

                const dad_adj = std.meta.intToEnum(Adjustment, self.cnt.dad_adj.read()) catch unreachable;
                if (dad_adj == .IncrementReload) self._dad = self.dad;
            }
        }

        pub fn enableSoundDma(self: *Self, fifo_addr: u32) void {
            comptime std.debug.assert(id == 1 or id == 2);

            if (self.cnt.enabled.read() and self.cnt.start_timing.read() == 0b11 and self.dad == fifo_addr) {
                self.active = true;
                self._word_count = 4;
                self.cnt.repeat.set();
            }
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
