const std = @import("std");
const util = @import("util.zig");
const bitfield = @import("bitfield");

const Bus = @import("bus.zig").Bus;
const Scheduler = @import("scheduler.zig").Scheduler;
const Bitfield = bitfield.Bitfield;
const Bit = bitfield.Bit;

const comptimeDataProcessing = @import("cpu/data_processing.zig").comptimeDataProcessing;
const comptimeSingleDataTransfer = @import("cpu/single_data_transfer.zig").comptimeSingleDataTransfer;
const comptimeHalfSignedDataTransfer = @import("cpu/half_signed_data_transfer.zig").comptimeHalfSignedDataTransfer;

pub const InstrFn = fn (*Arm7tdmi, *Bus, u32) void;
const arm_lut: [0x1000]InstrFn = populate();

pub const Arm7tdmi = struct {
    r: [16]u32,
    sch: *Scheduler,
    bus: *Bus,
    cpsr: CPSR,

    pub fn init(scheduler: *Scheduler, bus: *Bus) @This() {
        return .{
            .r = [_]u32{0x00} ** 16,
            .sch = scheduler,
            .bus = bus,
            .cpsr = .{ .val = 0x0000_00DF },
        };
    }

    pub inline fn step(self: *@This()) u64 {
        std.debug.print("PC: 0x{X:} ", .{self.r[15]});
        const opcode = self.fetch();
        std.debug.print("opcode: 0x{X:}\n", .{opcode}); // Debug

        if (checkCond(&self.cpsr, opcode)) arm_lut[armIdx(opcode)](self, self.bus, opcode);
        return 1;
    }

    fn fetch(self: *@This()) u32 {
        const word = self.bus.read32(self.r[15]);
        self.r[15] += 4;
        return word;
    }

    fn fakePC(self: *const @This()) u32 {
        return self.r[15] + 4;
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
        0xF => std.debug.panic("0xF is a reserved condition field", .{}),
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

                lut[i] = comptimeDataProcessing(I, S, instrKind);
            }

            if (i >> 9 & 0x7 == 0b000 and i >> 3 & 1 == 1 and i & 1 == 1) {
                const P = i >> 8 & 1 == 1;
                const U = i >> 7 & 1 == 1;
                const I = i >> 6 & 1 == 1;
                const W = i >> 5 & 1 == 1;
                const L = i >> 4 & 1 == 1;

                lut[i] = comptimeHalfSignedDataTransfer(P, U, I, W, L);
            }

            if (i >> 10 & 0x3 == 0b01) {
                const I = i >> 9 & 1 == 1;
                const P = i >> 8 & 1 == 1;
                const U = i >> 7 & 1 == 1;
                const B = i >> 6 & 1 == 1;
                const W = i >> 5 & 1 == 1;
                const L = i >> 4 & 1 == 1;

                lut[i] = comptimeSingleDataTransfer(I, P, U, B, W, L);
            }

            if (i >> 9 & 0x7 == 0b101) {
                const L = i >> 8 & 1 == 1;
                lut[i] = comptimeBranch(L);
            }
        }

        return lut;
    };
}

const CPSR = extern union {
    mode: Bitfield(u32, 0, 5),
    t: Bit(u32, 5),
    f: Bit(u32, 6),
    i: Bit(u32, 7),
    v: Bit(u32, 28),
    c: Bit(u32, 29),
    z: Bit(u32, 30),
    n: Bit(u32, 31),
    val: u32,
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
    std.debug.panic("[0x{X:}] 0x{X:} is an illegal opcode", .{ id, opcode });
}

fn comptimeBranch(comptime L: bool) InstrFn {
    return struct {
        fn branch(cpu: *Arm7tdmi, _: *Bus, opcode: u32) void {
            if (L) {
                cpu.r[14] = cpu.r[15] - 4;
            }

            cpu.r[15] = cpu.fakePC() +% util.u32SignExtend(24, opcode << 2);
        }
    }.branch;
}
