const std = @import("std");

const Bus = @import("../../Bus.zig");
const Arm7tdmi = @import("../../cpu.zig").Arm7tdmi;
const InstrFn = @import("../../cpu.zig").ThumbInstrFn;

pub fn format13(comptime _: bool) InstrFn {
    return struct {
        fn inner(_: *Arm7tdmi, _: *Bus, _: u16) void {
            std.debug.panic("[CPU|THUMB|Fmt13] Implement Format 13 THUMB Instructions", .{});
        }
    }.inner;
}
