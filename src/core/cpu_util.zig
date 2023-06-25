const std = @import("std");

const Arm7tdmi = @import("arm32").Arm7tdmi;
const Bank = @import("arm32").Arm7tdmi.Bank;
const Bus = @import("Bus.zig");

pub inline fn isHalted(cpu: *const Arm7tdmi) bool {
    const bus_ptr = @ptrCast(*Bus, @alignCast(@alignOf(Bus), cpu.bus.ptr));

    return bus_ptr.io.haltcnt == .Halt;
}

pub fn stepDmaTransfer(cpu: *Arm7tdmi) bool {
    const bus_ptr = @ptrCast(*Bus, @alignCast(@alignOf(Bus), cpu.bus.ptr));

    inline for (0..4) |i| {
        if (bus_ptr.dma[i].in_progress) {
            bus_ptr.dma[i].step(cpu);
            return true;
        }
    }

    return false;
}

pub fn handleInterrupt(cpu: *Arm7tdmi) void {
    const bus_ptr = @ptrCast(*Bus, @alignCast(@alignOf(Bus), cpu.bus.ptr));
    const should_handle = bus_ptr.io.ie.raw & bus_ptr.io.irq.raw;

    // Return if IME is disabled, CPSR I is set or there is nothing to handle
    if (!bus_ptr.io.ime or cpu.cpsr.i.read() or should_handle == 0) return;

    // If Pipeline isn't full, we have a bug
    std.debug.assert(cpu.pipe.isFull());

    // log.debug("Handling Interrupt!", .{});
    bus_ptr.io.haltcnt = .Execute;

    // FIXME: This seems weird, but retAddr.gba suggests I need to make these changes
    const ret_addr = cpu.r[15] - if (cpu.cpsr.t.read()) 0 else @as(u32, 4);
    const new_spsr = cpu.cpsr.raw;

    cpu.changeMode(.Irq);
    cpu.cpsr.t.write(false);
    cpu.cpsr.i.write(true);

    cpu.r[14] = ret_addr;
    cpu.spsr.raw = new_spsr;
    cpu.r[15] = 0x0000_0018;
    cpu.pipe.reload(cpu);
}

/// Advances state so that the BIOS is skipped
///
/// Note: This accesses the CPU's bus ptr so it only may be called
/// once the Bus has been properly initialized
///
/// TODO: Make above notice impossible to do in code
pub fn fastBoot(cpu: *Arm7tdmi) void {
    const bus_ptr = @ptrCast(*Bus, @alignCast(@alignOf(Bus), cpu.bus.ptr));
    cpu.r = std.mem.zeroes([16]u32);

    // cpu.r[0] = 0x08000000;
    // cpu.r[1] = 0x000000EA;
    cpu.r[13] = 0x0300_7F00;
    cpu.r[15] = 0x0800_0000;

    cpu.bank.r[Bank.regIdx(.Irq, .R13)] = 0x0300_7FA0;
    cpu.bank.r[Bank.regIdx(.Supervisor, .R13)] = 0x0300_7FE0;

    // cpu.cpsr.raw = 0x6000001F;
    cpu.cpsr.raw = 0x0000_001F;

    bus_ptr.bios.addr_latch = 0x0000_00DC + 8;
}
