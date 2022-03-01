const std = @import("std");

const DmaControl = @import("io.zig").DmaControl;
const Bus = @import("../Bus.zig");

const log = std.log.scoped(.DmaTransfer);

/// Function that creates a DMAController. Determines unique DMA Controller behaiour at compile-time
pub fn DmaController(comptime id: u2) type {
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
            }

            self.cnt.raw = halfword;
        }

        pub fn writeCnt(self: *Self, word: u32) void {
            self.word_count = @truncate(@TypeOf(self.word_count), word);
            self.writeCntHigh(@truncate(u16, word >> 16));
        }

        pub fn step(self: *Self, bus: *Bus) void {
            const sad_adj = std.meta.intToEnum(Adjustment, self.cnt.sad_adj.read()) catch unreachable;
            const dad_adj = std.meta.intToEnum(Adjustment, self.cnt.dad_adj.read()) catch unreachable;

            var offset: u32 = 0;
            if (self.cnt.transfer_type.read()) {
                offset = @sizeOf(u32); // 32-bit Transfer
                const word = bus.read32(self._sad);
                bus.write32(self._dad, word);
            } else {
                offset = @sizeOf(u16); // 16-bit Transfer
                const halfword = bus.read16(self._sad);
                bus.write16(self._dad, halfword);
            }

            switch (sad_adj) {
                .Increment => self._sad += offset,
                .Decrement => self._sad -= offset,
                .Fixed => {},

                // TODO: Figure out correct behaviour on Illegal Source Addr Control Type
                .IncrementReload => std.debug.panic("panic(DmaTransfer): {} is an illegal src addr adjustment type", .{sad_adj}),
            }

            switch (dad_adj) {
                .Increment, .IncrementReload => self._dad += offset,
                .Decrement => self._dad -= offset,
                .Fixed => {},
            }

            self._word_count -= 1;

            if (self._word_count == 0) {
                if (self.cnt.irq.read()) {
                    switch (id) {
                        0 => bus.io.irq.dma0.set(),
                        1 => bus.io.irq.dma0.set(),
                        2 => bus.io.irq.dma0.set(),
                        3 => bus.io.irq.dma0.set(),
                    }
                }

                self.cnt.enabled.unset();
            }
        }
    };
}

const Adjustment = enum(u2) {
    Increment = 0,
    Decrement = 1,
    Fixed = 2,
    IncrementReload = 3,
};
