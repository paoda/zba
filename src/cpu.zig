const std = @import("std");
const util = @import("util.zig");
const Bus = @import("bus.zig").Bus;
const Scheduler = @import("scheduler.zig").Scheduler;

const comptimeDataProcessing = @import("cpu/data_processing.zig").comptimeDataProcessing;
const comptimeSingleDataTransfer = @import("cpu/single_data_transfer.zig").comptimeSingleDataTransfer;
const comptimeHalfSignedDataTransfer = @import("cpu/half_signed_data_transfer.zig").comptimeHalfSignedDataTransfer;

pub const InstrFn = fn (*ARM7TDMI, *Bus, u32) void;
const ARM_LUT: [0x1000]InstrFn = populate();

pub const ARM7TDMI = struct {
    r: [16]u32,
    sch: *Scheduler,
    bus: *Bus,
    cpsr: CPSR,

    pub fn new(scheduler: *Scheduler, bus: *Bus) @This() {
        return .{
            .r = [_]u32{0x00} ** 16,
            .sch = scheduler,
            .bus = bus,
            .cpsr = .{ .inner = 0x0000_00DF },
        };
    }

    pub inline fn step(self: *@This()) u64 {
        const opcode = self.fetch();

        std.debug.print("R15: 0x{X:}\n", .{opcode}); // Debug

        ARM_LUT[armIdx(opcode)](self, self.bus, opcode);

        return 1;
    }

    fn fetch(self: *@This()) u32 {
        const word = self.bus.readWord(self.r[15]);
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

fn populate() [0x1000]InstrFn {
    return comptime {
        @setEvalBranchQuota(0x5000);
        var lut = [_]InstrFn{undefined_instr} ** 0x1000;

        var i: usize = 0;
        while (i < lut.len) : (i += 1) {
            if (i >> 10 & 0x3 == 0b00) {
                const I = i >> 9 & 0x01 == 0x01;
                const S = i >> 4 & 0x01 == 0x01;
                const instrKind = i >> 5 & 0x0F;

                lut[i] = comptimeDataProcessing(I, S, instrKind);
            }

            if (i >> 9 & 0x7 == 0b000 and i >> 3 & 0x01 == 0x01 and i & 0x01 == 0x01) {
                // Halfword and Signed Data Transfer with register offset
                const P = i >> 8 & 0x01 == 0x01;
                const U = i >> 7 & 0x01 == 0x01;
                const I = i >> 6 & 0x01 == 0x01;
                const W = i >> 5 & 0x01 == 0x01;
                const L = i >> 4 & 0x01 == 0x01;

                lut[i] = comptimeHalfSignedDataTransfer(P, U, I, W, L);
            }

            if (i >> 10 & 0x3 == 0b01) {
                const I = i >> 9 & 0x01 == 0x01;
                const P = i >> 8 & 0x01 == 0x01;
                const U = i >> 7 & 0x01 == 0x01;
                const B = i >> 6 & 0x01 == 0x01;
                const W = i >> 5 & 0x01 == 0x01;
                const L = i >> 4 & 0x01 == 0x01;

                lut[i] = comptimeSingleDataTransfer(I, P, U, B, W, L);
            }

            if (i >> 9 & 0x7 == 0b101) {
                const L = i >> 8 & 0x01 == 0x01;
                lut[i] = comptimeBranch(L);
            }
        }

        return lut;
    };
}

const CPSR = struct {
    inner: u32,

    pub fn n(self: *const @This()) bool {
        return self.inner >> 31 & 0x01 == 0x01;
    }

    pub fn set_n(self: *@This(), set: bool) void {
        self.set_bit(31, set);
    }

    pub fn z(self: *const @This()) bool {
        return self.inner >> 30 & 0x01 == 0x01;
    }

    pub fn set_z(self: *@This(), set: bool) void {
        self.set_bit(30, set);
    }

    pub fn c(self: *const @This()) bool {
        return self.inner >> 29 & 0x01 == 0x01;
    }

    pub fn set_c(self: *@This(), set: bool) void {
        self.set_bit(29, set);
    }

    pub fn v(self: *const @This()) bool {
        return self.inner >> 28 & 0x01 == 0x01;
    }

    pub fn set_v(self: *@This(), set: bool) void {
        self.set_bit(28, set);
    }
    
    pub fn i(self: *const @This()) bool {
        return self.inner >> 7 & 0x01 == 0x01;
    }

    pub fn set_i(self: *@This(), set: bool) void {
        self.set_bit(7, set);
    }

    pub fn f(self: *const @This()) bool {
        return self.inner >> 6 & 0x01 == 0x01;
    }

    pub fn set_f(self: *@This(), set: bool) void {
        self.set_bit(6, set);
    }

    pub fn t(self: *const @This()) bool {
        return self.inner >> 5 & 0x01 == 0x01;
    }

    pub fn set_t(self: *@This(), set: bool) void {
        self.set_bit(5, set);
    }

    pub fn mode(self: *const @This()) Mode {
        return self.inner & 0x1F;
    }
    
    pub fn set_mode(_: *@This(), _: Mode) void {
        std.debug.panic("TODO: Implement set_mode for CPSR", .{});
    }
    
    fn set_bit(self: *@This(), comptime bit: usize, set: bool) void {
        const set_val = @as(u32, @boolToInt(set)) << bit;
        const mask = ~(@as(u32, 1) << bit);
        
        self.inner = (self.inner & mask) | set_val;
    }
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

fn undefined_instr(_: *ARM7TDMI, _: *Bus, opcode: u32) void {
    const id = armIdx(opcode);
    std.debug.panic("[0x{X:}] 0x{X:} is an illegal opcode", .{ id, opcode });
}

fn comptimeBranch(comptime L: bool) InstrFn {
    return struct {
        fn branch(cpu: *ARM7TDMI, _: *Bus, opcode: u32) void {
            if (L) {
                cpu.r[14] = cpu.r[15] - 4;
            }

            cpu.r[15] = cpu.fakePC() + util.u32SignExtend(24, opcode << 2);
        }
    }.branch;
}
