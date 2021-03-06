const std = @import("std");
const util = @import("util.zig");

const Bus = @import("Bus.zig");
const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Scheduler = @import("scheduler.zig").Scheduler;
const FilePaths = @import("util.zig").FilePaths;
const Logger = @import("util.zig").Logger;

const File = std.fs.File;

// ARM Instructions
pub const arm = struct {
    pub const InstrFn = fn (*Arm7tdmi, *Bus, u32) void;
    const lut: [0x1000]InstrFn = populate();

    const processing = @import("cpu/arm/data_processing.zig").dataProcessing;
    const psrTransfer = @import("cpu/arm/psr_transfer.zig").psrTransfer;
    const transfer = @import("cpu/arm/single_data_transfer.zig").singleDataTransfer;
    const halfSignedTransfer = @import("cpu/arm/half_signed_data_transfer.zig").halfAndSignedDataTransfer;
    const blockTransfer = @import("cpu/arm/block_data_transfer.zig").blockDataTransfer;
    const branch = @import("cpu/arm/branch.zig").branch;
    const branchExchange = @import("cpu/arm/branch.zig").branchAndExchange;
    const swi = @import("cpu/arm/software_interrupt.zig").armSoftwareInterrupt;
    const swap = @import("cpu/arm/single_data_swap.zig").singleDataSwap;

    const multiply = @import("cpu/arm/multiply.zig").multiply;
    const multiplyLong = @import("cpu/arm/multiply.zig").multiplyLong;

    // Undefined ARM Instruction handler
    fn und(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
        const id = armIdx(opcode);
        cpu.panic("[CPU/Decode] ID: 0x{X:0>3} 0x{X:0>8} is an illegal opcode", .{ id, opcode });
    }

    fn populate() [0x1000]InstrFn {
        return comptime {
            @setEvalBranchQuota(0xE000);
            var ret = [_]InstrFn{und} ** 0x1000;

            var i: usize = 0;
            while (i < ret.len) : (i += 1) {
                ret[i] = switch (@as(u2, i >> 10)) {
                    0b00 => if (i == 0x121) blk: {
                        break :blk branchExchange;
                    } else if (i & 0xFCF == 0x009) blk: {
                        const A = i >> 5 & 1 == 1;
                        const S = i >> 4 & 1 == 1;
                        break :blk multiply(A, S);
                    } else if (i & 0xFBF == 0x109) blk: {
                        const B = i >> 6 & 1 == 1;
                        break :blk swap(B);
                    } else if (i & 0xF8F == 0x089) blk: {
                        const U = i >> 6 & 1 == 1;
                        const A = i >> 5 & 1 == 1;
                        const S = i >> 4 & 1 == 1;
                        break :blk multiplyLong(U, A, S);
                    } else if (i & 0xE49 == 0x009 or i & 0xE49 == 0x049) blk: {
                        const P = i >> 8 & 1 == 1;
                        const U = i >> 7 & 1 == 1;
                        const I = i >> 6 & 1 == 1;
                        const W = i >> 5 & 1 == 1;
                        const L = i >> 4 & 1 == 1;
                        break :blk halfSignedTransfer(P, U, I, W, L);
                    } else if (i & 0xD90 == 0x100) blk: {
                        const I = i >> 9 & 1 == 1;
                        const R = i >> 6 & 1 == 1;
                        const kind = i >> 4 & 0x3;
                        break :blk psrTransfer(I, R, kind);
                    } else blk: {
                        const I = i >> 9 & 1 == 1;
                        const S = i >> 4 & 1 == 1;
                        const instrKind = i >> 5 & 0xF;
                        break :blk processing(I, S, instrKind);
                    },
                    0b01 => if (i >> 9 & 1 == 1 and i & 1 == 1) und else blk: {
                        const I = i >> 9 & 1 == 1;
                        const P = i >> 8 & 1 == 1;
                        const U = i >> 7 & 1 == 1;
                        const B = i >> 6 & 1 == 1;
                        const W = i >> 5 & 1 == 1;
                        const L = i >> 4 & 1 == 1;
                        break :blk transfer(I, P, U, B, W, L);
                    },
                    else => switch (@as(u2, i >> 9 & 0x3)) {
                        // MSB is guaranteed to be 1
                        0b00 => blk: {
                            const P = i >> 8 & 1 == 1;
                            const U = i >> 7 & 1 == 1;
                            const S = i >> 6 & 1 == 1;
                            const W = i >> 5 & 1 == 1;
                            const L = i >> 4 & 1 == 1;
                            break :blk blockTransfer(P, U, S, W, L);
                        },
                        0b01 => blk: {
                            const L = i >> 8 & 1 == 1;
                            break :blk branch(L);
                        },
                        0b10 => und, // COP Data Transfer
                        0b11 => if (i >> 8 & 1 == 1) swi() else und, // COP Data Operation + Register Transfer
                    },
                };
            }

            return ret;
        };
    }
};

// THUMB Instructions
pub const thumb = struct {
    pub const InstrFn = fn (*Arm7tdmi, *Bus, u16) void;
    const lut: [0x400]InstrFn = populate();

    const processing = @import("cpu/thumb/data_processing.zig");
    const alu = @import("cpu/thumb/alu.zig").fmt4;
    const transfer = @import("cpu/thumb/data_transfer.zig");
    const block_transfer = @import("cpu/thumb/block_data_transfer.zig");
    const swi = @import("cpu/thumb/software_interrupt.zig").fmt17;
    const branch = @import("cpu/thumb/branch.zig");

    /// Undefined THUMB Instruction Handler
    fn und(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
        const id = thumbIdx(opcode);
        cpu.panic("[CPU/Decode] ID: 0b{b:0>10} 0x{X:0>2} is an illegal opcode", .{ id, opcode });
    }

    fn populate() [0x400]InstrFn {
        return comptime {
            @setEvalBranchQuota(5025); // This is exact
            var ret = [_]InstrFn{und} ** 0x400;

            var i: usize = 0;
            while (i < ret.len) : (i += 1) {
                ret[i] = switch (@as(u3, i >> 7 & 0x7)) {
                    0b000 => if (i >> 5 & 0x3 == 0b11) blk: {
                        const I = i >> 4 & 1 == 1;
                        const is_sub = i >> 3 & 1 == 1;
                        const rn = i & 0x7;
                        break :blk processing.fmt2(I, is_sub, rn);
                    } else blk: {
                        const op = i >> 5 & 0x3;
                        const offset = i & 0x1F;
                        break :blk processing.fmt1(op, offset);
                    },
                    0b001 => blk: {
                        const op = i >> 5 & 0x3;
                        const rd = i >> 2 & 0x7;
                        break :blk processing.fmt3(op, rd);
                    },
                    0b010 => switch (@as(u2, i >> 5 & 0x3)) {
                        0b00 => if (i >> 4 & 1 == 1) blk: {
                            const op = i >> 2 & 0x3;
                            const h1 = i >> 1 & 1;
                            const h2 = i & 1;
                            break :blk processing.fmt5(op, h1, h2);
                        } else blk: {
                            const op = i & 0xF;
                            break :blk alu(op);
                        },
                        0b01 => blk: {
                            const rd = i >> 2 & 0x7;
                            break :blk transfer.fmt6(rd);
                        },
                        else => blk: {
                            const op = i >> 4 & 0x3;
                            const T = i >> 3 & 1 == 1;
                            break :blk transfer.fmt78(op, T);
                        },
                    },
                    0b011 => blk: {
                        const B = i >> 6 & 1 == 1;
                        const L = i >> 5 & 1 == 1;
                        const offset = i & 0x1F;
                        break :blk transfer.fmt9(B, L, offset);
                    },
                    else => switch (@as(u3, i >> 6 & 0x7)) {
                        // MSB is guaranteed to be 1
                        0b000 => blk: {
                            const L = i >> 5 & 1 == 1;
                            const offset = i & 0x1F;
                            break :blk transfer.fmt10(L, offset);
                        },
                        0b001 => blk: {
                            const L = i >> 5 & 1 == 1;
                            const rd = i >> 2 & 0x7;
                            break :blk transfer.fmt11(L, rd);
                        },
                        0b010 => blk: {
                            const isSP = i >> 5 & 1 == 1;
                            const rd = i >> 2 & 0x7;
                            break :blk processing.fmt12(isSP, rd);
                        },
                        0b011 => if (i >> 4 & 1 == 1) blk: {
                            const L = i >> 5 & 1 == 1;
                            const R = i >> 2 & 1 == 1;
                            break :blk block_transfer.fmt14(L, R);
                        } else blk: {
                            const S = i >> 1 & 1 == 1;
                            break :blk processing.fmt13(S);
                        },
                        0b100 => blk: {
                            const L = i >> 5 & 1 == 1;
                            const rb = i >> 2 & 0x7;

                            break :blk block_transfer.fmt15(L, rb);
                        },
                        0b101 => if (i >> 2 & 0xF == 0b1111) blk: {
                            break :blk thumb.swi();
                        } else blk: {
                            const cond = i >> 2 & 0xF;
                            break :blk branch.fmt16(cond);
                        },
                        0b110 => branch.fmt18(),
                        0b111 => blk: {
                            const is_low = i >> 5 & 1 == 1;
                            break :blk branch.fmt19(is_low);
                        },
                    },
                };
            }

            return ret;
        };
    }
};

const cpu_logging = @import("emu.zig").cpu_logging;
const log = std.log.scoped(.Arm7Tdmi);

pub const Arm7tdmi = struct {
    const Self = @This();

    r: [16]u32,
    sched: *Scheduler,
    bus: *Bus,
    cpsr: PSR,
    spsr: PSR,

    /// Storage  for R8_fiq -> R12_fiq and their normal counterparts
    /// e.g [r[0 + 8], fiq_r[0 + 8], r[1 + 8], fiq_r[1 + 8]...]
    banked_fiq: [2 * 5]u32,

    /// Storage for r13_<mode>, r14_<mode>
    /// e.g. [r13, r14, r13_svc, r14_svc]
    banked_r: [2 * 6]u32,

    banked_spsr: [5]PSR,

    logger: ?Logger,

    pub fn init(sched: *Scheduler, bus: *Bus) Self {
        return Self{
            .r = [_]u32{0x00} ** 16,
            .sched = sched,
            .bus = bus,
            .cpsr = .{ .raw = 0x0000_001F },
            .spsr = .{ .raw = 0x0000_0000 },
            .banked_fiq = [_]u32{0x00} ** 10,
            .banked_r = [_]u32{0x00} ** 12,
            .banked_spsr = [_]PSR{.{ .raw = 0x0000_0000 }} ** 5,
            .logger = null,
        };
    }

    pub fn attach(self: *Self, log_file: std.fs.File) void {
        self.logger = Logger.init(log_file);
    }

    inline fn bankedIdx(mode: Mode, kind: BankedKind) usize {
        const idx: usize = switch (mode) {
            .User, .System => 0,
            .Supervisor => 1,
            .Abort => 2,
            .Undefined => 3,
            .Irq => 4,
            .Fiq => 5,
        };

        return (idx * 2) + if (kind == .R14) @as(usize, 1) else 0;
    }

    inline fn bankedSpsrIndex(mode: Mode) usize {
        return switch (mode) {
            .Supervisor => 0,
            .Abort => 1,
            .Undefined => 2,
            .Irq => 3,
            .Fiq => 4,
            else => std.debug.panic("[CPU/Mode] {} does not have a SPSR Register", .{mode}),
        };
    }

    inline fn bankedFiqIdx(i: usize, mode: Mode) usize {
        return (i * 2) + if (mode == .Fiq) @as(usize, 1) else 0;
    }

    pub inline fn hasSPSR(self: *const Self) bool {
        const mode = getModeChecked(self, self.cpsr.mode.read());
        return switch (mode) {
            .System, .User => false,
            else => true,
        };
    }

    pub inline fn isPrivileged(self: *const Self) bool {
        const mode = getModeChecked(self, self.cpsr.mode.read());
        return switch (mode) {
            .User => false,
            else => true,
        };
    }

    pub inline fn isHalted(self: *const Self) bool {
        return self.bus.io.haltcnt == .Halt;
    }

    pub fn setCpsr(self: *Self, value: u32) void {
        if (value & 0x1F != self.cpsr.raw & 0x1F) self.changeModeFromIdx(@truncate(u5, value & 0x1F));
        self.cpsr.raw = value;
    }

    fn changeModeFromIdx(self: *Self, next: u5) void {
        self.changeMode(getModeChecked(self, next));
    }

    pub fn setUserModeRegister(self: *Self, idx: usize, value: u32) void {
        const current = getModeChecked(self, self.cpsr.mode.read());

        switch (idx) {
            8...12 => {
                if (current == .Fiq) {
                    self.banked_fiq[bankedFiqIdx(idx - 8, .User)] = value;
                } else self.r[idx] = value;
            },
            13, 14 => switch (current) {
                .User, .System => self.r[idx] = value,
                else => {
                    const kind = std.meta.intToEnum(BankedKind, idx - 13) catch unreachable;
                    self.banked_r[bankedIdx(.User, kind)] = value;
                },
            },
            else => self.r[idx] = value, // R0 -> R7  and R15
        }
    }

    pub fn getUserModeRegister(self: *Self, idx: usize) u32 {
        const current = getModeChecked(self, self.cpsr.mode.read());

        return switch (idx) {
            8...12 => if (current == .Fiq) self.banked_fiq[bankedFiqIdx(idx - 8, .User)] else self.r[idx],
            13, 14 => switch (current) {
                .User, .System => self.r[idx],
                else => blk: {
                    const kind = std.meta.intToEnum(BankedKind, idx - 13) catch unreachable;
                    break :blk self.banked_r[bankedIdx(.User, kind)];
                },
            },
            else => self.r[idx], // R0 -> R7  and R15
        };
    }

    pub fn changeMode(self: *Self, next: Mode) void {
        const now = getModeChecked(self, self.cpsr.mode.read());

        // Bank R8 -> r12
        var i: usize = 0;
        while (i < 5) : (i += 1) {
            self.banked_fiq[bankedFiqIdx(i, now)] = self.r[8 + i];
        }

        // Bank r13, r14, SPSR
        switch (now) {
            .User, .System => {
                self.banked_r[bankedIdx(now, .R13)] = self.r[13];
                self.banked_r[bankedIdx(now, .R14)] = self.r[14];
            },
            else => {
                self.banked_r[bankedIdx(now, .R13)] = self.r[13];
                self.banked_r[bankedIdx(now, .R14)] = self.r[14];
                self.banked_spsr[bankedSpsrIndex(now)] = self.spsr;
            },
        }

        // Grab R8 -> R12
        i = 0;
        while (i < 5) : (i += 1) {
            self.r[8 + i] = self.banked_fiq[bankedFiqIdx(i, next)];
        }

        // Grab r13, r14, SPSR
        switch (next) {
            .User, .System => {
                self.r[13] = self.banked_r[bankedIdx(next, .R13)];
                self.r[14] = self.banked_r[bankedIdx(next, .R14)];
            },
            else => {
                self.r[13] = self.banked_r[bankedIdx(next, .R13)];
                self.r[14] = self.banked_r[bankedIdx(next, .R14)];
                self.spsr = self.banked_spsr[bankedSpsrIndex(next)];
            },
        }

        self.cpsr.mode.write(@enumToInt(next));
    }

    pub fn fastBoot(self: *Self) void {
        self.r = std.mem.zeroes([16]u32);

        self.r[0] = 0x08000000;
        self.r[1] = 0x000000EA;
        self.r[13] = 0x0300_7F00;
        self.r[15] = 0x0800_0000;

        self.banked_r[bankedIdx(.Irq, .R13)] = 0x0300_7FA0;
        self.banked_r[bankedIdx(.Supervisor, .R13)] = 0x0300_7FE0;

        self.cpsr.raw = 0x6000001F;
    }

    pub fn step(self: *Self) void {
        if (self.cpsr.t.read()) {
            const opcode = self.fetch(u16);
            if (cpu_logging) self.logger.?.mgbaLog(self, opcode);

            thumb.lut[thumbIdx(opcode)](self, self.bus, opcode);
        } else {
            const opcode = self.fetch(u32);
            if (cpu_logging) self.logger.?.mgbaLog(self, opcode);

            if (checkCond(self.cpsr, @truncate(u4, opcode >> 28))) {
                arm.lut[armIdx(opcode)](self, self.bus, opcode);
            }
        }
    }

    pub fn stepDmaTransfer(self: *Self) bool {
        const dma0 = &self.bus.dma[0];
        const dma1 = &self.bus.dma[1];
        const dma2 = &self.bus.dma[2];
        const dma3 = &self.bus.dma[3];

        if (dma0.in_progress) {
            dma0.step(self);
            return true;
        }

        if (dma1.in_progress) {
            dma1.step(self);
            return true;
        }

        if (dma2.in_progress) {
            dma2.step(self);
            return true;
        }

        if (dma3.in_progress) {
            dma3.step(self);
            return true;
        }

        return false;
    }

    pub fn handleInterrupt(self: *Self) void {
        const should_handle = self.bus.io.ie.raw & self.bus.io.irq.raw;

        if (should_handle != 0) {
            self.bus.io.haltcnt = .Execute;
            // log.debug("An Interrupt was Fired!", .{});

            // Either IME is not true or I in CPSR is true
            // Don't handle interrupts
            if (!self.bus.io.ime or self.cpsr.i.read()) return;
            // log.debug("An interrupt was Handled!", .{});

            // retAddr.gba says r15 on it's own is off by -04h in both ARM and THUMB mode
            const r15 = self.r[15] + 4;
            const cpsr = self.cpsr.raw;

            self.changeMode(.Irq);
            self.cpsr.t.write(false);
            self.cpsr.i.write(true);

            self.r[14] = r15;
            self.spsr.raw = cpsr;
            self.r[15] = 0x000_0018;
        }
    }

    inline fn fetch(self: *Self, comptime T: type) T {
        comptime std.debug.assert(T == u32 or T == u16); // Opcode may be 32-bit (ARM) or 16-bit (THUMB)
        defer self.r[15] += if (T == u32) 4 else 2;

        // FIXME: You better hope this is optimized out
        const tick_cache = self.sched.tick;
        defer self.sched.tick = tick_cache + Bus.fetch_timings[@boolToInt(T == u32)][@truncate(u4, self.r[15] >> 24)];

        return self.bus.read(T, self.r[15]);
    }

    pub fn fakePC(self: *const Self) u32 {
        return self.r[15] + 4;
    }

    pub fn panic(self: *const Self, comptime format: []const u8, args: anytype) noreturn {
        var i: usize = 0;
        while (i < 16) : (i += 4) {
            const i_1 = i + 1;
            const i_2 = i + 2;
            const i_3 = i + 3;
            std.debug.print("R{}: 0x{X:0>8}\tR{}: 0x{X:0>8}\tR{}: 0x{X:0>8}\tR{}: 0x{X:0>8}\n", .{ i, self.r[i], i_1, self.r[i_1], i_2, self.r[i_2], i_3, self.r[i_3] });
        }
        std.debug.print("cpsr: 0x{X:0>8} ", .{self.cpsr.raw});
        prettyPrintPsr(&self.cpsr);

        std.debug.print("spsr: 0x{X:0>8} ", .{self.spsr.raw});
        prettyPrintPsr(&self.spsr);

        if (self.cpsr.t.read()) {
            const opcode = self.bus.debugRead(u16, self.r[15] - 4);
            const id = thumbIdx(opcode);
            std.debug.print("opcode: ID: 0x{b:0>10} 0x{X:0>4}\n", .{ id, opcode });
        } else {
            const opcode = self.bus.debugRead(u32, self.r[15] - 4);
            const id = armIdx(opcode);
            std.debug.print("opcode: ID: 0x{X:0>3} 0x{X:0>8}\n", .{ id, opcode });
        }

        std.debug.print("tick: {}\n\n", .{self.sched.tick});

        std.debug.panic(format, args);
    }

    fn prettyPrintPsr(psr: *const PSR) void {
        std.debug.print("[", .{});

        if (psr.n.read()) std.debug.print("N", .{}) else std.debug.print("-", .{});
        if (psr.z.read()) std.debug.print("Z", .{}) else std.debug.print("-", .{});
        if (psr.c.read()) std.debug.print("C", .{}) else std.debug.print("-", .{});
        if (psr.v.read()) std.debug.print("V", .{}) else std.debug.print("-", .{});
        if (psr.i.read()) std.debug.print("I", .{}) else std.debug.print("-", .{});
        if (psr.f.read()) std.debug.print("F", .{}) else std.debug.print("-", .{});
        if (psr.t.read()) std.debug.print("T", .{}) else std.debug.print("-", .{});
        std.debug.print("|", .{});
        if (getMode(psr.mode.read())) |mode| std.debug.print("{s}", .{modeString(mode)}) else std.debug.print("---", .{});

        std.debug.print("]\n", .{});
    }

    fn modeString(mode: Mode) []const u8 {
        return switch (mode) {
            .User => "usr",
            .Fiq => "fiq",
            .Irq => "irq",
            .Supervisor => "svc",
            .Abort => "abt",
            .Undefined => "und",
            .System => "sys",
        };
    }

    fn mgbaLog(self: *const Self, file: *const File, opcode: u32) !void {
        const thumb_fmt = "{X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} cpsr: {X:0>8} | {X:0>4}:\n";
        const arm_fmt = "{X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} cpsr: {X:0>8} | {X:0>8}:\n";
        var buf: [0x100]u8 = [_]u8{0x00} ** 0x100; // this is larger than it needs to be

        const r0 = self.r[0];
        const r1 = self.r[1];
        const r2 = self.r[2];
        const r3 = self.r[3];
        const r4 = self.r[4];
        const r5 = self.r[5];
        const r6 = self.r[6];
        const r7 = self.r[7];
        const r8 = self.r[8];
        const r9 = self.r[9];
        const r10 = self.r[10];
        const r11 = self.r[11];
        const r12 = self.r[12];
        const r13 = self.r[13];
        const r14 = self.r[14];
        const r15 = self.r[15];

        const c_psr = self.cpsr.raw;

        var log_str: []u8 = undefined;
        if (self.cpsr.t.read()) {
            if (opcode >> 11 == 0x1E) {
                // Instruction 1 of a BL Opcode, print in ARM mode
                const other_half = self.bus.debugRead(u16, self.r[15]);
                const bl_opcode = @as(u32, opcode) << 16 | other_half;

                log_str = try std.fmt.bufPrint(&buf, arm_fmt, .{ r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, c_psr, bl_opcode });
            } else {
                log_str = try std.fmt.bufPrint(&buf, thumb_fmt, .{ r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, c_psr, opcode });
            }
        } else {
            log_str = try std.fmt.bufPrint(&buf, arm_fmt, .{ r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, c_psr, opcode });
        }

        _ = try file.writeAll(log_str);
    }
};

inline fn armIdx(opcode: u32) u12 {
    return @truncate(u12, opcode >> 20 & 0xFF) << 4 | @truncate(u12, opcode >> 4 & 0xF);
}

inline fn thumbIdx(opcode: u16) u10 {
    return @truncate(u10, opcode >> 6);
}

pub fn checkCond(cpsr: PSR, cond: u4) bool {
    return switch (cond) {
        0x0 => cpsr.z.read(), // EQ - Equal
        0x1 => !cpsr.z.read(), // NE - Not equal
        0x2 => cpsr.c.read(), // CS - Unsigned higher or same
        0x3 => !cpsr.c.read(), // CC - Unsigned lower
        0x4 => cpsr.n.read(), // MI - Negative
        0x5 => !cpsr.n.read(), // PL - Positive or zero
        0x6 => cpsr.v.read(), // VS - Overflow
        0x7 => !cpsr.v.read(), // VC - No overflow
        0x8 => cpsr.c.read() and !cpsr.z.read(), // HI - unsigned higher
        0x9 => !cpsr.c.read() or cpsr.z.read(), // LS - unsigned lower or same
        0xA => cpsr.n.read() == cpsr.v.read(), // GE - Greater or equal
        0xB => cpsr.n.read() != cpsr.v.read(), // LT - Less than
        0xC => !cpsr.z.read() and (cpsr.n.read() == cpsr.v.read()), // GT - Greater than
        0xD => cpsr.z.read() or (cpsr.n.read() != cpsr.v.read()), // LE - Less than or equal
        0xE => true, // AL - Always
        0xF => false, // NV - Never (reserved in ARMv3 and up, but seems to have not changed?)
    };
}

pub const PSR = extern union {
    mode: Bitfield(u32, 0, 5),
    t: Bit(u32, 5),
    f: Bit(u32, 6),
    i: Bit(u32, 7),
    v: Bit(u32, 28),
    c: Bit(u32, 29),
    z: Bit(u32, 30),
    n: Bit(u32, 31),
    raw: u32,
};

const Mode = enum(u5) {
    User = 0b10000,
    Fiq = 0b10001,
    Irq = 0b10010,
    Supervisor = 0b10011,
    Abort = 0b10111,
    Undefined = 0b11011,
    System = 0b11111,
};

const BankedKind = enum(u1) {
    R13 = 0,
    R14,
};

fn getMode(bits: u5) ?Mode {
    return std.meta.intToEnum(Mode, bits) catch null;
}

fn getModeChecked(cpu: *const Arm7tdmi, bits: u5) Mode {
    return getMode(bits) orelse cpu.panic("[CPU/CPSR] 0b{b:0>5} is an invalid CPU mode", .{bits});
}
