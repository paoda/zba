const std = @import("std");

const Bus = @import("../Bus.zig");
const Arm7tdmi = @import("../cpu.zig").Arm7tdmi;
const InstrFn = @import("../cpu.zig").InstrFn;

pub fn psrTransfer(comptime _: bool, comptime _: bool) InstrFn {
    return struct {
        fn inner(_: *Arm7tdmi, _: *Bus, _: u32) void {
            std.debug.panic("[CPU] TODO: Implement PSR Transfer Instructions", .{});
        }
    }.inner;
}
