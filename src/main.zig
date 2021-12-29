const std = @import("std");

const Scheduler = @import("scheduler.zig").Scheduler;
const Bus = @import("bus.zig").Bus;
const ARM7TDMI = @import("cpu.zig").ARM7TDMI;

const emu = @import("emu.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    // defer gpa.deinit();

    var bus = try Bus.withPak(alloc, "./bin/demo/beeg/beeg.gba");
    var scheduler = Scheduler.new(alloc);
    var cpu = ARM7TDMI.new(&scheduler, &bus);

    while (true) {
        emu.runFrame(&scheduler, &cpu, &bus);
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
