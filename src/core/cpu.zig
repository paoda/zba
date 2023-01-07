const std = @import("std");

const Bus = @import("Bus.zig");
const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Scheduler = @import("scheduler.zig").Scheduler;
const Logger = @import("../util.zig").Logger;

const File = std.fs.File;
const log = std.log.scoped(.Arm7Tdmi);

// ARM Instructions
pub const arm = struct {
    pub const InstrFn = *const fn (*Arm7tdmi, *Bus, u32) void;
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

    /// Determine index into ARM InstrFn LUT
    fn idx(opcode: u32) u12 {
        return @truncate(u12, opcode >> 20 & 0xFF) << 4 | @truncate(u12, opcode >> 4 & 0xF);
    }

    // Undefined ARM Instruction handler
    fn und(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
        const id = idx(opcode);
        cpu.panic("[CPU/Decode] ID: 0x{X:0>3} 0x{X:0>8} is an illegal opcode", .{ id, opcode });
    }

    fn populate() [0x1000]InstrFn {
        comptime {
            @setEvalBranchQuota(0xE000);
            var table = [_]InstrFn{und} ** 0x1000;

            for (&table, 0..) |*handler, i| {
                handler.* = switch (@as(u2, i >> 10)) {
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

            return table;
        }
    }
};

// THUMB Instructions
pub const thumb = struct {
    pub const InstrFn = *const fn (*Arm7tdmi, *Bus, u16) void;
    const lut: [0x400]InstrFn = populate();

    const processing = @import("cpu/thumb/data_processing.zig");
    const alu = @import("cpu/thumb/alu.zig").fmt4;
    const transfer = @import("cpu/thumb/data_transfer.zig");
    const block_transfer = @import("cpu/thumb/block_data_transfer.zig");
    const swi = @import("cpu/thumb/software_interrupt.zig").fmt17;
    const branch = @import("cpu/thumb/branch.zig");

    /// Determine index into THUMB InstrFn LUT
    fn idx(opcode: u16) u10 {
        return @truncate(u10, opcode >> 6);
    }

    /// Undefined THUMB Instruction Handler
    fn und(cpu: *Arm7tdmi, _: *Bus, opcode: u16) void {
        const id = idx(opcode);
        cpu.panic("[CPU/Decode] ID: 0b{b:0>10} 0x{X:0>2} is an illegal opcode", .{ id, opcode });
    }

    fn populate() [0x400]InstrFn {
        comptime {
            @setEvalBranchQuota(5025); // This is exact
            var table = [_]InstrFn{und} ** 0x400;

            for (&table, 0..) |*handler, i| {
                handler.* = switch (@as(u3, i >> 7 & 0x7)) {
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

            return table;
        }
    }
};

pub const Arm7tdmi = struct {
    const Self = @This();

    r: [16]u32,
    pipe: Pipeline,
    sched: *Scheduler,
    bus: *Bus,
    cpsr: PSR,
    spsr: PSR,

    bank: Bank,

    logger: ?Logger,

    /// Bank of Registers from other CPU Modes
    const Bank = struct {
        /// Storage for r13_<mode>, r14_<mode>
        /// e.g. [r13, r14, r13_svc, r14_svc]
        r: [2 * 6]u32,

        /// Storage  for R8_fiq -> R12_fiq and their normal counterparts
        /// e.g [r[0 + 8], fiq_r[0 + 8], r[1 + 8], fiq_r[1 + 8]...]
        fiq: [2 * 5]u32,

        spsr: [5]PSR,

        const Kind = enum(u1) {
            R13 = 0,
            R14,
        };

        pub fn create() Bank {
            return .{
                .r = [_]u32{0x00} ** 12,
                .fiq = [_]u32{0x00} ** 10,
                .spsr = [_]PSR{.{ .raw = 0x0000_0000 }} ** 5,
            };
        }

        inline fn regIdx(mode: Mode, kind: Kind) usize {
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

        inline fn spsrIdx(mode: Mode) usize {
            return switch (mode) {
                .Supervisor => 0,
                .Abort => 1,
                .Undefined => 2,
                .Irq => 3,
                .Fiq => 4,
                else => std.debug.panic("[CPU/Mode] {} does not have a SPSR Register", .{mode}),
            };
        }

        inline fn fiqIdx(i: usize, mode: Mode) usize {
            return (i * 2) + if (mode == .Fiq) @as(usize, 1) else 0;
        }
    };

    pub fn init(sched: *Scheduler, bus: *Bus, log_file: ?std.fs.File) Self {
        return Self{
            .r = [_]u32{0x00} ** 16,
            .pipe = Pipeline.init(),
            .sched = sched,
            .bus = bus,
            .cpsr = .{ .raw = 0x0000_001F },
            .spsr = .{ .raw = 0x0000_0000 },
            .bank = Bank.create(),
            .logger = if (log_file) |file| Logger.init(file) else null,
        };
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
                    self.bank.fiq[Bank.fiqIdx(idx - 8, .User)] = value;
                } else self.r[idx] = value;
            },
            13, 14 => switch (current) {
                .User, .System => self.r[idx] = value,
                else => {
                    const kind = std.meta.intToEnum(Bank.Kind, idx - 13) catch unreachable;
                    self.bank.r[Bank.regIdx(.User, kind)] = value;
                },
            },
            else => self.r[idx] = value, // R0 -> R7  and R15
        }
    }

    pub fn getUserModeRegister(self: *Self, idx: usize) u32 {
        const current = getModeChecked(self, self.cpsr.mode.read());

        return switch (idx) {
            8...12 => if (current == .Fiq) self.bank.fiq[Bank.fiqIdx(idx - 8, .User)] else self.r[idx],
            13, 14 => switch (current) {
                .User, .System => self.r[idx],
                else => blk: {
                    const kind = std.meta.intToEnum(Bank.Kind, idx - 13) catch unreachable;
                    break :blk self.bank.r[Bank.regIdx(.User, kind)];
                },
            },
            else => self.r[idx], // R0 -> R7  and R15
        };
    }

    pub fn changeMode(self: *Self, next: Mode) void {
        const now = getModeChecked(self, self.cpsr.mode.read());

        // Bank R8 -> r12
        for (0..5) |i| {
            self.bank.fiq[Bank.fiqIdx(i, now)] = self.r[8 + i];
        }

        // Bank r13, r14, SPSR
        switch (now) {
            .User, .System => {
                self.bank.r[Bank.regIdx(now, .R13)] = self.r[13];
                self.bank.r[Bank.regIdx(now, .R14)] = self.r[14];
            },
            else => {
                self.bank.r[Bank.regIdx(now, .R13)] = self.r[13];
                self.bank.r[Bank.regIdx(now, .R14)] = self.r[14];
                self.bank.spsr[Bank.spsrIdx(now)] = self.spsr;
            },
        }

        // Grab R8 -> R12
        for (0..5) |i| {
            self.r[8 + i] = self.bank.fiq[Bank.fiqIdx(i, next)];
        }

        // Grab r13, r14, SPSR
        switch (next) {
            .User, .System => {
                self.r[13] = self.bank.r[Bank.regIdx(next, .R13)];
                self.r[14] = self.bank.r[Bank.regIdx(next, .R14)];
            },
            else => {
                self.r[13] = self.bank.r[Bank.regIdx(next, .R13)];
                self.r[14] = self.bank.r[Bank.regIdx(next, .R14)];
                self.spsr = self.bank.spsr[Bank.spsrIdx(next)];
            },
        }

        self.cpsr.mode.write(@enumToInt(next));
    }

    /// Advances state so that the BIOS is skipped
    ///
    /// Note: This accesses the CPU's bus ptr so it only may be called
    /// once the Bus has been properly initialized
    ///
    /// TODO: Make above notice impossible to do in code
    pub fn fastBoot(self: *Self) void {
        self.r = std.mem.zeroes([16]u32);

        // self.r[0] = 0x08000000;
        // self.r[1] = 0x000000EA;
        self.r[13] = 0x0300_7F00;
        self.r[15] = 0x0800_0000;

        self.bank.r[Bank.regIdx(.Irq, .R13)] = 0x0300_7FA0;
        self.bank.r[Bank.regIdx(.Supervisor, .R13)] = 0x0300_7FE0;

        // self.cpsr.raw = 0x6000001F;
        self.cpsr.raw = 0x0000_001F;

        self.bus.bios.addr_latch = 0x0000_00DC + 8;
    }

    pub fn step(self: *Self) void {
        defer {
            if (!self.pipe.flushed) self.r[15] += if (self.cpsr.t.read()) 2 else @as(u32, 4);
            self.pipe.flushed = false;
        }

        if (self.cpsr.t.read()) {
            const opcode = @truncate(u16, self.pipe.step(self, u16) orelse return);
            if (self.logger) |*trace| trace.mgbaLog(self, opcode);

            thumb.lut[thumb.idx(opcode)](self, self.bus, opcode);
        } else {
            const opcode = self.pipe.step(self, u32) orelse return;
            if (self.logger) |*trace| trace.mgbaLog(self, opcode);

            if (checkCond(self.cpsr, @truncate(u4, opcode >> 28))) {
                arm.lut[arm.idx(opcode)](self, self.bus, opcode);
            }
        }
    }

    pub fn stepDmaTransfer(self: *Self) bool {
        inline for (0..4) |i| {
            if (self.bus.dma[i].in_progress) {
                self.bus.dma[i].step(self);
                return true;
            }
        }

        return false;
    }

    pub fn handleInterrupt(self: *Self) void {
        const should_handle = self.bus.io.ie.raw & self.bus.io.irq.raw;

        // Return if IME is disabled, CPSR I is set or there is nothing to handle
        if (!self.bus.io.ime or self.cpsr.i.read() or should_handle == 0) return;

        // If Pipeline isn't full, we have a bug
        std.debug.assert(self.pipe.isFull());

        // log.debug("Handling Interrupt!", .{});
        self.bus.io.haltcnt = .Execute;

        // FIXME: This seems weird, but retAddr.gba suggests I need to make these changes
        const ret_addr = self.r[15] - if (self.cpsr.t.read()) 0 else @as(u32, 4);
        const new_spsr = self.cpsr.raw;

        self.changeMode(.Irq);
        self.cpsr.t.write(false);
        self.cpsr.i.write(true);

        self.r[14] = ret_addr;
        self.spsr.raw = new_spsr;
        self.r[15] = 0x0000_0018;
        self.pipe.reload(self);
    }

    inline fn fetch(self: *Self, comptime T: type, address: u32) T {
        comptime std.debug.assert(T == u32 or T == u16); // Opcode may be 32-bit (ARM) or 16-bit (THUMB)

        // Bus.read will advance the scheduler. There are different timings for CPU fetches,
        // so we want to undo what Bus.read will apply. We can do this by caching the current tick
        // This is very dumb.
        //
        // FIXME: Please rework this
        const tick_cache = self.sched.tick;
        defer self.sched.tick = tick_cache + Bus.fetch_timings[@boolToInt(T == u32)][@truncate(u4, address >> 24)];

        return self.bus.read(T, address);
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
        self.cpsr.toString();

        std.debug.print("spsr: 0x{X:0>8} ", .{self.spsr.raw});
        self.spsr.toString();

        std.debug.print("pipeline: {??X:0>8}\n", .{self.pipe.stage});

        if (self.cpsr.t.read()) {
            const opcode = self.bus.dbgRead(u16, self.r[15] - 4);
            const id = thumb.idx(opcode);
            std.debug.print("opcode: ID: 0x{b:0>10} 0x{X:0>4}\n", .{ id, opcode });
        } else {
            const opcode = self.bus.dbgRead(u32, self.r[15] - 4);
            const id = arm.idx(opcode);
            std.debug.print("opcode: ID: 0x{X:0>3} 0x{X:0>8}\n", .{ id, opcode });
        }

        std.debug.print("tick: {}\n\n", .{self.sched.tick});

        std.debug.panic(format, args);
    }
};

const condition_lut = [_]u16{
    0xF0F0, // EQ - Equal
    0x0F0F, // NE - Not Equal
    0xCCCC, // CS - Unsigned higher or same
    0x3333, // CC - Unsigned lower
    0xFF00, // MI - Negative
    0x00FF, // PL - Positive or Zero
    0xAAAA, // VS - Overflow
    0x5555, // VC - No Overflow
    0x0C0C, // HI - unsigned hierh
    0xF3F3, // LS - unsigned lower or same
    0xAA55, // GE - greater or equal
    0x55AA, // LT - less than
    0x0A05, // GT - greater than
    0xF5FA, // LE - less than or equal
    0xFFFF, // AL - always
    0x0000, // NV - never
};

pub inline fn checkCond(cpsr: PSR, cond: u4) bool {
    const flags = @truncate(u4, cpsr.raw >> 28);

    return condition_lut[cond] & (@as(u16, 1) << flags) != 0;
}

const Pipeline = struct {
    const Self = @This();
    stage: [2]?u32,
    flushed: bool,

    fn init() Self {
        return .{
            .stage = [_]?u32{null} ** 2,
            .flushed = false,
        };
    }

    pub fn isFull(self: *const Self) bool {
        return self.stage[0] != null and self.stage[1] != null;
    }

    pub fn step(self: *Self, cpu: *Arm7tdmi, comptime T: type) ?u32 {
        comptime std.debug.assert(T == u32 or T == u16);

        const opcode = self.stage[0];
        self.stage[0] = self.stage[1];
        self.stage[1] = cpu.fetch(T, cpu.r[15]);

        return opcode;
    }

    pub fn reload(self: *Self, cpu: *Arm7tdmi) void {
        if (cpu.cpsr.t.read()) {
            self.stage[0] = cpu.fetch(u16, cpu.r[15]);
            self.stage[1] = cpu.fetch(u16, cpu.r[15] + 2);
            cpu.r[15] += 4;
        } else {
            self.stage[0] = cpu.fetch(u32, cpu.r[15]);
            self.stage[1] = cpu.fetch(u32, cpu.r[15] + 4);
            cpu.r[15] += 8;
        }

        self.flushed = true;
    }
};

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

    fn toString(self: PSR) void {
        std.debug.print("[", .{});

        if (self.n.read()) std.debug.print("N", .{}) else std.debug.print("-", .{});
        if (self.z.read()) std.debug.print("Z", .{}) else std.debug.print("-", .{});
        if (self.c.read()) std.debug.print("C", .{}) else std.debug.print("-", .{});
        if (self.v.read()) std.debug.print("V", .{}) else std.debug.print("-", .{});
        if (self.i.read()) std.debug.print("I", .{}) else std.debug.print("-", .{});
        if (self.f.read()) std.debug.print("F", .{}) else std.debug.print("-", .{});
        if (self.t.read()) std.debug.print("T", .{}) else std.debug.print("-", .{});
        std.debug.print("|", .{});
        if (getMode(self.mode.read())) |m| std.debug.print("{s}", .{m.toString()}) else std.debug.print("---", .{});

        std.debug.print("]\n", .{});
    }
};

pub const Mode = enum(u5) {
    User = 0b10000,
    Fiq = 0b10001,
    Irq = 0b10010,
    Supervisor = 0b10011,
    Abort = 0b10111,
    Undefined = 0b11011,
    System = 0b11111,

    pub fn toString(self: Mode) []const u8 {
        return switch (self) {
            .User => "usr",
            .Fiq => "fiq",
            .Irq => "irq",
            .Supervisor => "svc",
            .Abort => "abt",
            .Undefined => "und",
            .System => "sys",
        };
    }
};

fn getMode(bits: u5) ?Mode {
    return std.meta.intToEnum(Mode, bits) catch null;
}

fn getModeChecked(cpu: *const Arm7tdmi, bits: u5) Mode {
    return getMode(bits) orelse cpu.panic("[CPU/CPSR] 0b{b:0>5} is an invalid CPU mode", .{bits});
}
