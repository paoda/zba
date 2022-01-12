const std = @import("std");
const util = @import("util.zig");

const BarrelShifter = @import("cpu/barrel_shifter.zig");
const Bus = @import("Bus.zig");
const Bit = @import("bitfield").Bit;
const Bitfield = @import("bitfield").Bitfield;
const Scheduler = @import("scheduler.zig").Scheduler;

const dataProcessing = @import("cpu/data_processing.zig").dataProcessing;
const psrTransfer = @import("cpu/psr_transfer.zig").psrTransfer;
const singleDataTransfer = @import("cpu/single_data_transfer.zig").singleDataTransfer;
const halfAndSignedDataTransfer = @import("cpu/half_signed_data_transfer.zig").halfAndSignedDataTransfer;
const blockDataTransfer = @import("cpu/block_data_transfer.zig").blockDataTransfer;
const branch = @import("cpu/branch.zig").branch;

pub const InstrFn = fn (*Arm7tdmi, *Bus, u32) void;
const arm_lut: [0x1000]InstrFn = populate();

pub const Arm7tdmi = struct {
    const Self = @This();

    r: [16]u32,
    sched: *Scheduler,
    bus: *Bus,
    cpsr: CPSR,

    pub fn init(sched: *Scheduler, bus: *Bus) Self {
        return .{
            .r = [_]u32{0x00} ** 16,
            .sched = sched,
            .bus = bus,
            .cpsr = .{ .raw = 0x0000_00DF },
        };
    }

    pub fn skipBios(self: *Self) void {
        self.r[0] = 0x08000000;
        self.r[1] = 0x000000EA;
        // GPRs 2 -> 12 *should* already be 0 initialized
        self.r[13] = 0x0300_7F00;
        self.r[14] = 0x0000_0000;
        self.r[15] = 0x0800_0000;

        // TODO: Set sp_irq = 0x0300_7FA0, sp_svc = 0x0300_7FE0

        self.cpsr.raw = 0x6000001F;
    }

    pub fn step(self: *Self) u64 {
        const opcode = self.fetch();
        // self.mgbaLog(opcode);

        if (checkCond(&self.cpsr, opcode)) arm_lut[armIdx(opcode)](self, self.bus, opcode);
        return 1;
    }

    fn fetch(self: *Self) u32 {
        const word = self.bus.read32(self.r[15]);
        self.r[15] += 4;
        return word;
    }

    pub fn fakePC(self: *const Self) u32 {
        return self.r[15] + 4;
    }

    fn mgbaLog(self: *const Self, opcode: u32) void {
        const stderr = std.io.getStdErr().writer();
        std.debug.getStderrMutex().lock();
        defer std.debug.getStderrMutex().unlock();

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

        const cpsr = self.cpsr.raw;

        nosuspend stderr.print("{X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} {X:0>8} cpsr: {X:0>8} | {X:0>8}:\n", .{ r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, cpsr, opcode }) catch return;
    }
};

fn armIdx(opcode: u32) u12 {
    return @truncate(u12, opcode >> 20 & 0xFF) << 4 | @truncate(u12, opcode >> 4 & 0xF);
}

fn checkCond(cpsr: *const CPSR, opcode: u32) bool {
    // TODO: Should I implement an enum?
    return switch (@truncate(u4, opcode >> 28)) {
        0x0 => cpsr.z.read(), // EQ - Equal
        0x1 => !cpsr.z.read(), // NEQ - Not equal
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
        0xC => !cpsr.z.read() and (cpsr.n.read() == cpsr.z.read()), // GT - Greater than
        0xD => cpsr.z.read() or (cpsr.n.read() != cpsr.v.read()), // LE - Less than or equal
        0xE => true, // AL - Always
        0xF => std.debug.panic("[CPU] 0xF is a reserved condition field", .{}),
    };
}

fn populate() [0x1000]InstrFn {
    return comptime {
        @setEvalBranchQuota(0x5000); // TODO: Figure out exact size
        var lut = [_]InstrFn{undefinedInstruction} ** 0x1000;

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
                const isSpsr = i >> 6 & 1 == 1;

                lut[i] = psrTransfer(I, isSpsr);
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
        }

        return lut;
    };
}

pub const CPSR = extern union {
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
    FIQ = 0b10001,
    IRQ = 0b10010,
    Supervisor = 0b10011,
    Abort = 0b10111,
    Undefined = 0b11011,
    System = 0b11111,
};

fn undefinedInstruction(_: *Arm7tdmi, _: *Bus, opcode: u32) void {
    const id = armIdx(opcode);
    std.debug.panic("[CPU] {{0x{X:}}} 0x{X:} is an illegal opcode", .{ id, opcode });
}
