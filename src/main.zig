const std = @import("std");
const emu = @import("emu.zig");

const Scheduler = @import("scheduler.zig").Scheduler;
const Bus = @import("bus.zig").Bus;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

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

    var bus = try Bus.init(alloc, zba_args[0]);
    var scheduler = Scheduler.init(alloc);
    var cpu = Arm7tdmi.init(&scheduler, &bus);

    while (true) {
        emu.runFrame(&scheduler, &cpu, &bus);
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
