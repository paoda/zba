const std = @import("std");
const builtin = @import("builtin");

const known_folders = @import("known_folders");
const clap = @import("clap");

const Gui = @import("Gui.zig");
const Bus = @import("core/Bus.zig");
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FilePaths = @import("core/util.zig").FilePaths;

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.CLI);
const width = @import("core/ppu.zig").width;
const height = @import("core/ppu.zig").height;
const cpu_logging = @import("core/emu.zig").cpu_logging;
pub const log_level = if (builtin.mode != .Debug) .info else std.log.default_level;

// TODO: Reimpl Logging

// CLI Arguments + Help Text
const params = clap.parseParamsComptime(
    \\-h, --help            Display this help and exit.
    \\-b, --bios <str>      Optional path to a GBA BIOS ROM.
    \\<str>                 Path to the GBA GamePak ROM
    \\
);

pub fn main() anyerror!void {
    // Main Allocator for ZBA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = gpa.allocator();

    // Handle CLI Input
    const result = try clap.parse(clap.Help, &params, clap.parsers.default, .{});
    defer result.deinit();

    const paths = try handleArguments(allocator, &result);
    defer if (paths.save) |path| allocator.free(path);

    const log_file: ?std.fs.File = if (cpu_logging) try std.fs.cwd().createFile("zba.log", .{}) else null;
    defer if (log_file) |file| file.close();

    // TODO: Take Emulator Init Code out of main.zig
    var scheduler = Scheduler.init(allocator);
    defer scheduler.deinit();

    var bus: Bus = undefined;
    var cpu = Arm7tdmi.init(&scheduler, &bus, log_file);
    if (paths.bios == null) cpu.fastBoot();

    try bus.init(allocator, &scheduler, &cpu, paths);
    bus.pak.setupGpio(); // FIXME: Can I not call this in main()?
    defer bus.deinit();

    var gui = Gui.init(bus.pak.title, width, height);
    gui.initAudio(&bus.apu);
    defer gui.deinit();

    try gui.run(&cpu, &scheduler);
}

fn getSavePath(allocator: Allocator) !?[]const u8 {
    const save_subpath = "zba" ++ [_]u8{std.fs.path.sep} ++ "save";

    const maybe_data_path = try known_folders.getPath(allocator, .data);
    defer if (maybe_data_path) |path| allocator.free(path);

    const save_path = if (maybe_data_path) |base| try std.fs.path.join(allocator, &[_][]const u8{ base, "zba", "save" }) else null;

    if (save_path) |_| {
        // If we've determined what our save path should be, ensure the prereq directories
        // are present so that we can successfully write to the path when necessary
        const maybe_data_dir = try known_folders.open(allocator, .data, .{});
        if (maybe_data_dir) |data_dir| try data_dir.makePath(save_subpath);
    }

    return save_path;
}

fn getRomPath(result: *const clap.Result(clap.Help, &params, clap.parsers.default)) ![]const u8 {
    return switch (result.positionals.len) {
        1 => result.positionals[0],
        0 => std.debug.panic("ZBA requires a positional path to a GamePak ROM.\n", .{}),
        else => std.debug.panic("ZBA received too many arguments.\n", .{}),
    };
}

pub fn handleArguments(allocator: Allocator, result: *const clap.Result(clap.Help, &params, clap.parsers.default)) !FilePaths {
    const rom_path = try getRomPath(result);
    log.info("ROM path: {s}", .{rom_path});
    const bios_path = result.args.bios;
    if (bios_path) |path| log.info("BIOS path: {s}", .{path}) else log.info("No BIOS provided", .{});
    const save_path = try getSavePath(allocator);
    if (save_path) |path| log.info("Save path: {s}", .{path});

    return FilePaths{
        .rom = rom_path,
        .bios = bios_path,
        .save = save_path,
    };
}
