const std = @import("std");
const builtin = @import("builtin");
const known_folders = @import("known_folders");
const clap = @import("clap");

const config = @import("config.zig");
const emu = @import("core/emu.zig");

const Synchro = @import("core/emu.zig").Synchro;
const Gui = @import("platform.zig").Gui;
const Bus = @import("core/Bus.zig");
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FilePaths = @import("util.zig").FilePaths;
const FpsTracker = @import("util.zig").FpsTracker;
const Allocator = std.mem.Allocator;

const Arm7tdmi = @import("arm32").Arm7tdmi;
const IBus = @import("arm32").Bus;
const IScheduler = @import("arm32").Scheduler;

const log = std.log.scoped(.Cli);
pub const log_level = if (builtin.mode != .Debug) .info else std.log.default_level;

// CLI Arguments + Help Text
const params = clap.parseParamsComptime(
    \\-h, --help            Display this help and exit.
    \\-s, --skip            Skip BIOS.
    \\-b, --bios <str>      Optional path to a GBA BIOS ROM.
    \\ --gdb                Run ZBA from the context of a GDB Server
    \\<str>                 Path to the GBA GamePak ROM.
    \\
);

pub fn main() !void {
    // Main Allocator for ZBA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    // Determine the Data Directory (stores saves)
    const data_path = blk: {
        const path = (try known_folders.getPath(allocator, .data)) orelse return error.unknown_data_folder;
        try makePath(path, "zba" ++ std.fs.path.sep_str ++ "save");

        break :blk path;
    };
    defer allocator.free(data_path);

    // Determine the Config Directory
    const config_path = blk: {
        const path = (try known_folders.getPath(allocator, .roaming_configuration)) orelse return error.unknown_config_folder;
        try makePath(path, "zba");

        break :blk path;
    };
    defer allocator.free(config_path);

    // Parse CLI
    const result = try clap.parse(clap.Help, &params, clap.parsers.default, .{ .allocator = allocator });
    defer result.deinit();

    // TODO: Move config file to XDG Config directory?
    try makeConfigFilePath(config_path);
    try config.load(allocator, config_path);

    var paths = try handleArguments(allocator, data_path, &result);
    defer paths.deinit(allocator);

    // if paths.bios is null, then we want to see if it's in the data directory
    if (paths.bios == null) blk: {
        const bios_path = try std.mem.join(allocator, "/", &.{ data_path, "zba", "gba_bios.bin" }); // FIXME: std.fs.path_sep or something
        defer allocator.free(bios_path);

        _ = std.fs.cwd().statFile(bios_path) catch |e| {
            if (e != std.fs.Dir.StatFileError.FileNotFound) return e;

            log.err("file located at {s} was not found", .{bios_path});
            break :blk;
        };

        paths.bios = try allocator.dupe(u8, bios_path);
    }

    const log_file = switch (config.config().debug.cpu_trace) {
        true => try std.fs.cwd().createFile("zba.log", .{}),
        false => null,
    };
    defer if (log_file) |file| file.close();

    // TODO: Take Emulator Init Code out of main.zig
    var scheduler = Scheduler.init(allocator);
    defer scheduler.deinit();

    var bus: Bus = undefined;

    const ischeduler = IScheduler.init(&scheduler);
    const ibus = IBus.init(&bus);

    var cpu = Arm7tdmi.init(ischeduler, ibus);

    try bus.init(allocator, &scheduler, &cpu, paths);
    defer bus.deinit();

    if (config.config().guest.skip_bios or result.args.skip != 0 or paths.bios == null) {
        @import("core/cpu_util.zig").fastBoot(&cpu);
    }

    const title_ptr = if (paths.rom != null) &bus.pak.title else null;

    // TODO: Just copy the title instead of grabbing a pointer to it
    var gui = try Gui.init(allocator, &bus.apu, title_ptr);
    defer gui.deinit();

    var sync = try Synchro.init(allocator);
    defer sync.deinit(allocator);

    if (result.args.gdb != 0) {
        const Server = @import("gdbstub").Server;
        const EmuThing = @import("core/emu.zig").EmuThing;

        var wrapper = EmuThing.init(&cpu, &scheduler);
        var emulator = wrapper.interface();
        defer emulator.deinit(allocator);

        log.info("Ready to connect", .{});

        var server = try Server.init(emulator, .{ .memory_map = EmuThing.map, .target = EmuThing.target });
        defer server.deinit(allocator);

        log.info("Starting GDB Server Thread", .{});

        const thread = try std.Thread.spawn(.{}, Server.run, .{ &server, allocator, &sync.should_quit });
        defer thread.join();

        try gui.run(.{ .cpu = &cpu, .scheduler = &scheduler, .sync = &sync });
    } else {
        var tracker = FpsTracker.init();

        const thread = try std.Thread.spawn(.{}, emu.run, .{ &cpu, &scheduler, &tracker, &sync });
        defer thread.join();

        try gui.run(.{ .cpu = &cpu, .scheduler = &scheduler, .tracker = &tracker, .sync = &sync });
    }
}

fn handleArguments(allocator: Allocator, data_path: []const u8, result: *const clap.Result(clap.Help, &params, clap.parsers.default)) !FilePaths {
    const rom_path = try romPath(allocator, result);
    errdefer if (rom_path) |path| allocator.free(path);

    const bios_path: ?[]const u8 = if (result.args.bios) |path| try allocator.dupe(u8, path) else null;
    errdefer if (bios_path) |path| allocator.free(path);

    const save_path = try std.fs.path.join(allocator, &[_][]const u8{ data_path, "zba", "save" });

    log.info("ROM path: {?s}", .{rom_path});
    log.info("BIOS path: {?s}", .{bios_path});
    log.info("Save path: {s}", .{save_path});

    return .{
        .rom = rom_path,
        .bios = bios_path,
        .save = save_path,
    };
}

fn makeConfigFilePath(config_path: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(config_path, .{});
    defer dir.close();

    const sub_path = "zba" ++ std.fs.path.sep_str ++ "config.toml";

    // We try to create the file exclusively, meaning that we err out if the file already exists.
    // All we care about is a file being there so we can just ignore that error in particular and
    // continue down the happy pathj
    dir.access(sub_path, .{}) catch |e| {
        if (e != std.fs.Dir.AccessError.FileNotFound) return e;

        const config_file = try dir.createFile(sub_path, .{});
        defer config_file.close();

        try config_file.writeAll(@embedFile("example.toml"));
    };
}

fn romPath(allocator: Allocator, result: *const clap.Result(clap.Help, &params, clap.parsers.default)) !?[]const u8 {
    return switch (result.positionals.len) {
        0 => null,
        1 => if (result.positionals[0]) |path| try allocator.dupe(u8, path) else null,
        else => error.too_many_positional_arguments,
    };
}

fn makePath(path: []const u8, sub_path: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(path, .{});
    defer dir.close();

    try dir.makePath(sub_path);
}
