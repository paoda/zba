const std = @import("std");
const emu = @import("emu.zig");

const Scheduler = @import("scheduler.zig").Scheduler;
const Bus = @import("bus.zig").Bus;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer std.debug.assert(!gpa.deinit());

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const zba_args: []const []const u8 = args[1..];

    if (zba_args.len == 0) {
        std.log.err("Expected PATH to Gameboy Advance ROM as a CLI argument", .{});
        return;
    } else if (zba_args.len > 1) {
        std.log.err("Too many CLI arguments were provided", .{});
        return;
    }

    var scheduler = Scheduler.init(alloc);
    defer scheduler.deinit();

    var bus = try Bus.init(alloc, &scheduler, zba_args[0]);
    defer bus.deinit();

    var cpu = Arm7tdmi.init(&scheduler, &bus);

    cpu.skipBios();

    while (true) {
        emu.runFrame(&scheduler, &cpu, &bus);
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
