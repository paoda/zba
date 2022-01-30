const std = @import("std");
const util = @import("util.zig");

const Bus = @import("Bus.zig");
const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Scheduler = @import("scheduler.zig").Scheduler;

const File = std.fs.File;

// ARM Instruction Groups
const dataProcessing = @import("cpu/arm/data_processing.zig").dataProcessing;
const psrTransfer = @import("cpu/arm/psr_transfer.zig").psrTransfer;
const singleDataTransfer = @import("cpu/arm/single_data_transfer.zig").singleDataTransfer;
const halfAndSignedDataTransfer = @import("cpu/arm/half_signed_data_transfer.zig").halfAndSignedDataTransfer;
const blockDataTransfer = @import("cpu/arm/block_data_transfer.zig").blockDataTransfer;
const branch = @import("cpu/arm/branch.zig").branch;
const branchAndExchange = @import("cpu/arm/branch.zig").branchAndExchange;
const softwareInterrupt = @import("cpu/arm/software_interrupt.zig").softwareInterrupt;

// THUMB Instruction Groups
const format1 = @import("cpu/thumb/format1.zig").format1;
const format2 = @import("cpu/thumb/format2.zig").format2;
const format3 = @import("cpu/thumb/format3.zig").format3;
const format4 = @import("cpu/thumb/format4.zig").format4;
const format5 = @import("cpu/thumb/format5.zig").format5;
const format6 = @import("cpu/thumb/format6.zig").format6;
const format9 = @import("cpu/thumb/format9.zig").format9;
const format12 = @import("cpu/thumb/format12.zig").format12;
const format13 = @import("cpu/thumb/format13.zig").format13;
const format14 = @import("cpu/thumb/format14.zig").format14;
const format15 = @import("cpu/thumb/format15.zig").format15;
const format16 = @import("cpu/thumb/format16.zig").format16;
const format19 = @import("cpu/thumb/format19.zig").format19;

pub const ArmInstrFn = fn (*Arm7tdmi, *Bus, u32) void;
pub const ThumbInstrFn = fn (*Arm7tdmi, *Bus, u16) void;
const arm_lut: [0x1000]ArmInstrFn = armPopulate();
const thumb_lut: [0x400]ThumbInstrFn = thumbPopulate();

const enable_logging = @import("main.zig").enable_logging;

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

    log_file: ?*const File,
    log_buf: [0x100]u8,
    binary_log: bool,

    pub fn init(sched: *Scheduler, bus: *Bus) Self {
        return .{
            .r = [_]u32{0x00} ** 16,
            .sched = sched,
            .bus = bus,
            .cpsr = .{ .raw = 0x0000_00DF },
            .spsr = .{ .raw = 0x0000_0000 },
            .banked_fiq = [_]u32{0x00} ** 10,
            .banked_r = [_]u32{0x00} ** 12,
            .banked_spsr = [_]PSR{.{ .raw = 0x0000_0000 }} ** 5,
            .log_file = null,
            .log_buf = undefined,
            .binary_log = false,
        };
    }

    pub fn useLogger(self: *Self, file: *const File, is_binary: bool) void {
        self.log_file = file;
        self.binary_log = is_binary;
    }

    inline fn bankedIdx(mode: Mode) usize {
        return switch (mode) {
            .User, .System => 0,
            .Supervisor => 1,
            .Abort => 2,
            .Undefined => 3,
            .Irq => 4,
            .Fiq => 5,
        };
    }

    inline fn spsrIdx(mode: Mode) usize {
        return switch (mode) {
            .Supervisor => 0,
            .Abort => 1,
            .Undefined => 2,
            .Irq => 3,
            .Fiq => 4,
            else => std.debug.panic("{} does not have a SPSR Register", .{mode}),
        };
    }

    pub inline fn hasSPSR(self: *const Self) bool {
        return switch (getMode(self.cpsr.mode.read())) {
            .System, .User => false,
            else => true,
        };
    }

    pub inline fn isPrivileged(self: *const Self) bool {
        return switch (getMode(self.cpsr.mode.read())) {
            .User => false,
            else => true,
        };
    }

    pub fn setCpsr(self: *Self, value: u32) void {
        if (value & 0x1F != self.cpsr.raw & 0x1F) self.changeModeFromIdx(@truncate(u5, value & 0x1F));
        self.cpsr.raw = value;
    }

    fn changeModeFromIdx(self: *Self, next: u5) void {
        self.changeMode(getMode(next));
    }

    pub fn changeMode(self: *Self, next: Mode) void {
        const now = getMode(self.cpsr.mode.read());

        // Bank R8 -> r12
        var r: usize = 8;
        while (r <= 12) : (r += 1) {
            self.banked_fiq[(r - 8) * 2 + if (now == .Fiq) @as(usize, 1) else 0] = self.r[r];
        }

        // Bank r13, r14, SPSR
        switch (now) {
            .User, .System => {
                self.banked_r[bankedIdx(now) * 2 + 0] = self.r[13];
                self.banked_r[bankedIdx(now) * 2 + 1] = self.r[14];
            },
            else => {
                self.banked_r[bankedIdx(now) * 2 + 0] = self.r[13];
                self.banked_r[bankedIdx(now) * 2 + 1] = self.r[14];
                self.banked_spsr[spsrIdx(now)] = self.spsr;
            },
        }

        // Grab R8 -> R12
        r = 8;
        while (r <= 12) : (r += 1) {
            self.r[r] = self.banked_fiq[(r - 8) * 2 + if (next == .Fiq) @as(usize, 1) else 0];
        }

        // Grab r13, r14, SPSR
        switch (next) {
            .User, .System => {
                self.r[13] = self.banked_r[bankedIdx(next) * 2 + 0];
                self.r[14] = self.banked_r[bankedIdx(next) * 2 + 1];
                // FIXME: Should we clear out SPSR?
            },
            else => {
                self.r[13] = self.banked_r[bankedIdx(next) * 2 + 0];
                self.r[14] = self.banked_r[bankedIdx(next) * 2 + 1];
                self.spsr = self.banked_spsr[spsrIdx(next)];
            },
        }

        self.cpsr.mode.write(@enumToInt(next));
    }

    pub fn fastBoot(self: *Self) void {
        self.r[0] = 0x08000000;
        self.r[1] = 0x000000EA;
        // GPRs 2 -> 12 *should* already be 0 initialized
        self.r[13] = 0x0300_7F00;
        self.r[14] = 0x0000_0000;
        self.r[15] = 0x0800_0000;

        // Set r13_irq and r14_svc to their respective values
        self.banked_r[bankedIdx(.Irq) * 2 + 0] = 0x0300_7FA0;
        self.banked_r[bankedIdx(.Supervisor) * 2 + 0] = 0x0300_7FE0;

        self.cpsr.raw = 0x6000001F;
    }

    pub fn step(self: *Self) u64 {
        if (self.cpsr.t.read()) {
            const opcode = self.thumbFetch();
            if (enable_logging) if (self.log_file) |file| self.log(file, @as(u32, opcode));

            thumb_lut[thumbIdx(opcode)](self, self.bus, opcode);
        } else {
            const opcode = self.fetch();
            if (enable_logging) if (self.log_file) |file| self.log(file, opcode);

            if (checkCond(self.cpsr, @truncate(u4, opcode >> 28))) {
                arm_lut[armIdx(opcode)](self, self.bus, opcode);
            }
        }

        return 1;
    }

    fn thumbFetch(self: *Self) u16 {
        const halfword = self.bus.read16(self.r[15]);
        self.r[15] += 2;
        return halfword;
    }

    fn fetch(self: *Self) u32 {
        const word = self.bus.read32(self.r[15]);
        self.r[15] += 4;
        return word;
    }

    pub fn fakePC(self: *const Self) u32 {
        return self.r[15] + 4;
    }

    fn log(self: *const Self, file: *const File, opcode: u32) void {
        if (self.binary_log) {
            self.skyLog(file) catch unreachable;
        } else {
            self.mgbaLog(file, opcode) catch unreachable;
        }
    }

    fn skyLog(self: *const Self, file: *const File) !void {
        var buf: [18 * @sizeOf(u32)]u8 = undefined;

        // Write Registers
        var i: usize = 0;
        while (i < 0x10) : (i += 1) {
            skyWrite(&buf, i, self.r[i]);
        }

        skyWrite(&buf, 0x10, self.cpsr.raw);
        skyWrite(&buf, 0x11, if (self.hasSPSR()) self.spsr.raw else self.cpsr.raw);
        _ = try file.writeAll(&buf);
    }

    fn skyWrite(buf: []u8, i: usize, num: u32) void {
        buf[(@sizeOf(u32) * i) + 3] = @truncate(u8, num >> 24 & 0xFF);
        buf[(@sizeOf(u32) * i) + 2] = @truncate(u8, num >> 16 & 0xFF);
        buf[(@sizeOf(u32) * i) + 1] = @truncate(u8, num >> 8 & 0xFF);
        buf[(@sizeOf(u32) * i) + 0] = @truncate(u8, num >> 0 & 0xFF);
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
                const tmp_opcode = self.bus.read32(self.r[15] - 2);
                const be_opcode = tmp_opcode << 16 | tmp_opcode >> 16;
                log_str = try std.fmt.bufPrint(&buf, arm_fmt, .{ r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, c_psr, be_opcode });
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
    // TODO: Should I implement an enum?
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
        0x9 => !cpsr.c.read() and cpsr.z.read(), // LS - unsigned lower or same
        0xA => cpsr.n.read() == cpsr.v.read(), // GE - Greater or equal
        0xB => cpsr.n.read() != cpsr.v.read(), // LT - Less than
        0xC => !cpsr.z.read() and (cpsr.n.read() == cpsr.v.read()), // GT - Greater than
        0xD => cpsr.z.read() or (cpsr.n.read() != cpsr.v.read()), // LE - Less than or equal
        0xE => true, // AL - Always
        0xF => std.debug.panic("[CPU] 0xF is a reserved condition field", .{}),
    };
}

fn thumbPopulate() [0x400]ThumbInstrFn {
    return comptime {
        @setEvalBranchQuota(0xC00);
        var lut = [_]ThumbInstrFn{thumbUndefined} ** 0x400;

        var i: usize = 0;
        while (i < lut.len) : (i += 1) {
            if (i >> 7 & 0x7 == 0b000) {
                const op = i >> 5 & 0x3;
                const offset = i & 0x1F;

                lut[i] = format1(op, offset);
            }
            if (i >> 5 & 0x1F == 0b00011) {
                const I = i >> 4 & 1 == 1;
                const is_sub = i >> 3 & 1 == 1;
                const rn = i & 0x7;

                lut[i] = format2(I, is_sub, rn);
            }

            if (i >> 7 & 0x7 == 0b001) {
                const op = i >> 5 & 0x3;
                const rd = i >> 2 & 0x7;

                lut[i] = format3(op, rd);
            }

            if (i >> 4 & 0x3F == 0b010000) {
                const op = i & 0xF;

                lut[i] = format4(op);
            }

            if (i >> 4 & 0x3F == 0b010001) {
                const op = i >> 2 & 0x3;
                const h1 = i >> 1 & 1;
                const h2 = i & 1;

                lut[i] = format5(op, h1, h2);
            }

            if (i >> 5 & 0x1F == 0b01001) {
                const rd = i >> 2 & 0x7;

                lut[i] = format6(rd);
            }

            if (i >> 7 & 0x7 == 0b011) {
                const B = i >> 6 & 1 == 1;
                const L = i >> 5 & 1 == 1;
                const offset = i & 0x1F;

                lut[i] = format9(B, L, offset);
            }

            if (i >> 6 & 0xF == 0b1010) {
                const isSP = i >> 5 & 1 == 1;
                const rd = i >> 2 & 0x7;

                lut[i] = format12(isSP, rd);
            }

            if (i >> 2 & 0xFF == 0xB0) {
                const S = i >> 1 & 1 == 1;

                lut[i] = format13(S);
            }

            if (i >> 6 & 0xF == 0b1011 and i >> 3 & 0x3 == 0b10) {
                const L = i >> 5 & 1 == 1;
                const R = i >> 2 & 1 == 1;

                lut[i] = format14(L, R);
            }

            if (i >> 6 & 0xF == 0b1100) {
                const L = i >> 5 & 1 == 1;
                const rb = i >> 2 & 0x7;

                lut[i] = format15(L, rb);
            }

            if (i >> 6 & 0xF == 0b1101) {
                const cond = i >> 2 & 0xF;

                lut[i] = format16(cond);
            }

            if (i >> 6 & 0xF == 0b1111) {
                const is_low = i >> 5 & 1 == 1;

                lut[i] = format19(is_low);
            }
        }

        return lut;
    };
}

fn armPopulate() [0x1000]ArmInstrFn {
    return comptime {
        @setEvalBranchQuota(0x5000); // TODO: Figure out exact size
        var lut = [_]ArmInstrFn{armUndefined} ** 0x1000;

        var i: usize = 0;
        while (i < lut.len) : (i += 1) {
            if (i >> 10 & 0x3 == 0b00) {
                const I = i >> 9 & 1 == 1;
                const S = i >> 4 & 1 == 1;
                const instrKind = i >> 5 & 0xF;

                lut[i] = dataProcessing(I, S, instrKind);
            }

            if (i >> 10 & 0x3 == 0b00 and i >> 7 & 0x3 == 0b10 and i >> 4 & 1 == 0) {
                // PSR Transfer
                const I = i >> 9 & 1 == 1;
                const R = i >> 6 & 1 == 1;
                const kind = i >> 4 & 0x3;

                lut[i] = psrTransfer(I, R, kind);
            }

            if (i == 0x121) {
                lut[i] = branchAndExchange;
            }

            if (i >> 9 & 0x7 == 0b000 and i >> 3 & 1 == 1 and i & 1 == 1) {
                const P = i >> 8 & 1 == 1;
                const U = i >> 7 & 1 == 1;
                const I = i >> 6 & 1 == 1;
                const W = i >> 5 & 1 == 1;
                const L = i >> 4 & 1 == 1;

                lut[i] = halfAndSignedDataTransfer(P, U, I, W, L);
            }

            if (i >> 10 & 0x3 == 0b01) {
                const I = i >> 9 & 1 == 1;
                const P = i >> 8 & 1 == 1;
                const U = i >> 7 & 1 == 1;
                const B = i >> 6 & 1 == 1;
                const W = i >> 5 & 1 == 1;
                const L = i >> 4 & 1 == 1;

                lut[i] = singleDataTransfer(I, P, U, B, W, L);
            }

            if (i >> 9 & 0x7 == 0b100) {
                const P = i >> 8 & 1 == 1;
                const U = i >> 7 & 1 == 1;
                const S = i >> 6 & 1 == 1;
                const W = i >> 5 & 1 == 1;
                const L = i >> 4 & 1 == 1;

                lut[i] = blockDataTransfer(P, U, S, W, L);
            }

            if (i >> 9 & 0x7 == 0b101) {
                const L = i >> 8 & 1 == 1;
                lut[i] = branch(L);
            }

            if (i >> 8 & 0xF == 0b1111) lut[i] = softwareInterrupt();
        }

        return lut;
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

pub fn getMode(bits: u5) Mode {
    return std.meta.intToEnum(Mode, bits) catch unreachable;
}

fn armUndefined(_: *Arm7tdmi, _: *Bus, opcode: u32) void {
    const id = armIdx(opcode);
    std.debug.panic("[CPU:ARM] ID: 0x{X:0>3} 0x{X:0>8} is an illegal opcode", .{ id, opcode });
}

fn thumbUndefined(_: *Arm7tdmi, _: *Bus, opcode: u16) void {
    const id = thumbIdx(opcode);
    std.debug.panic("[CPU:THUMB] ID: 0b{b:0>10} 0x{X:0>2} is an illegal opcode", .{ id, opcode });
}
