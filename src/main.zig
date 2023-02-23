const std = @import("std");
const builtin = @import("builtin");
const known_folders = @import("known_folders");
const clap = @import("clap");

const config = @import("config.zig");
const emu = @import("core/emu.zig");

const Gui = @import("platform.zig").Gui;
const Bus = @import("core/Bus.zig");
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FilePaths = @import("util.zig").FilePaths;
const FpsTracker = @import("util.zig").FpsTracker;
const Allocator = std.mem.Allocator;
const Atomic = std.atomic.Atomic;

const log = std.log.scoped(.Cli);
const width = @import("core/ppu.zig").width;
const height = @import("core/ppu.zig").height;
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

pub fn main() void {
    // Main Allocator for ZBA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = gpa.allocator();

    // Determine the Data Directory (stores saves)
    const data_path = blk: {
        const result = known_folders.getPath(allocator, .data);
        const option = result catch |e| exitln("interrupted while determining the data folder: {}", .{e});
        const path = option orelse exitln("no valid data folder found", .{});
        ensureDataDirsExist(path) catch |e| exitln("failed to create folders under \"{s}\": {}", .{ path, e });

        break :blk path;
    };
    defer allocator.free(data_path);

    // Determine the Config Directory
    const config_path = blk: {
        const result = known_folders.getPath(allocator, .roaming_configuration);
        const option = result catch |e| exitln("interreupted while determining the config folder: {}", .{e});
        const path = option orelse exitln("no valid config folder found", .{});
        ensureConfigDirExists(path) catch |e| exitln("failed to create required folder \"{s}\": {}", .{ path, e });

        break :blk path;
    };
    defer allocator.free(config_path);

    // Parse CLI
    const result = clap.parse(clap.Help, &params, clap.parsers.default, .{}) catch |e| exitln("failed to parse cli: {}", .{e});
    defer result.deinit();

    // TODO: Move config file to XDG Config directory?
    const cfg_file_path = configFilePath(allocator, config_path) catch |e| exitln("failed to ready config file for access: {}", .{e});
    defer allocator.free(cfg_file_path);

    config.load(allocator, cfg_file_path) catch |e| exitln("failed to load config file: {}", .{e});

    const paths = handleArguments(allocator, data_path, &result) catch |e| exitln("failed to handle cli arguments: {}", .{e});
    defer if (paths.save) |path| allocator.free(path);

    const log_file = if (config.config().debug.cpu_trace) blk: {
        break :blk std.fs.cwd().createFile("zba.log", .{}) catch |e| exitln("failed to create trace log file: {}", .{e});
    } else null;
    defer if (log_file) |file| file.close();

    // TODO: Take Emulator Init Code out of main.zig
    var scheduler = Scheduler.init(allocator);
    defer scheduler.deinit();

    var bus: Bus = undefined;
    var cpu = Arm7tdmi.init(&scheduler, &bus, log_file);

    bus.init(allocator, &scheduler, &cpu, paths) catch |e| exitln("failed to init zba bus: {}", .{e});
    defer bus.deinit();

    if (config.config().guest.skip_bios or result.args.skip or paths.bios == null) {
        cpu.fastBoot();
    }

    var quit = Atomic(bool).init(false);
    var gui = Gui.init(&bus.pak.title, &bus.apu, width, height) catch |e| exitln("failed to init gui: {}", .{e});
    defer gui.deinit();

    if (result.args.gdb) {
        const Server = @import("gdbstub").Server;
        const EmuThing = @import("core/emu.zig").EmuThing;

        var wrapper = EmuThing.init(&cpu, &scheduler);
        var emulator = wrapper.interface(allocator);
        defer emulator.deinit();

        log.info("Ready to connect", .{});

        var server = Server.init(emulator) catch |e| exitln("failed to init gdb server: {}", .{e});
        defer server.deinit(allocator);

        log.info("Starting GDB Server Thread", .{});

        const thread = std.Thread.spawn(.{}, Server.run, .{ &server, allocator, &quit }) catch |e| exitln("gdb server thread crashed: {}", .{e});
        defer thread.join();

        gui.run(.{
            .cpu = &cpu,
            .scheduler = &scheduler,
            .quit = &quit,
        }) catch |e| exitln("main thread panicked: {}", .{e});
    } else {
        var tracker = FpsTracker.init();

        const thread = std.Thread.spawn(.{}, emu.run, .{ &quit, &scheduler, &cpu, &tracker }) catch |e| exitln("emu thread panicked: {}", .{e});
        defer thread.join();

        gui.run(.{
            .cpu = &cpu,
            .scheduler = &scheduler,
            .tracker = &tracker,
            .quit = &quit,
        }) catch |e| exitln("main thread panicked: {}", .{e});
    }
}

fn handleArguments(allocator: Allocator, data_path: []const u8, result: *const clap.Result(clap.Help, &params, clap.parsers.default)) !FilePaths {
    const rom_path = romPath(result);
    log.info("ROM path: {s}", .{rom_path});

    const bios_path = result.args.bios;
    if (bios_path) |path| log.info("BIOS path: {s}", .{path}) else log.warn("No BIOS provided", .{});

    const save_path = try std.fs.path.join(allocator, &[_][]const u8{ data_path, "zba", "save" });
    log.info("Save path: {s}", .{save_path});

    return .{
        .rom = rom_path,
        .bios = bios_path,
        .save = save_path,
    };
}

fn configFilePath(allocator: Allocator, config_path: []const u8) ![]const u8 {
    const path = try std.fs.path.join(allocator, &[_][]const u8{ config_path, "zba", "config.toml" });
    errdefer allocator.free(path);

    // We try to create the file exclusively, meaning that we err out if the file already exists.
    // All we care about is a file being there so we can just ignore that error in particular and
    // continue down the happy pathj
    std.fs.accessAbsolute(path, .{}) catch |e| {
        if (e != error.FileNotFound) return e;

        const config_file = std.fs.createFileAbsolute(path, .{}) catch |err| exitln("failed to create \"{s}\": {}", .{ path, err });
        defer config_file.close();

        try config_file.writeAll(@embedFile("../example.toml"));
    };

    return path;
}

fn ensureDataDirsExist(data_path: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(data_path, .{});
    defer dir.close();

    // Will recursively create directories
    try dir.makePath("zba" ++ std.fs.path.sep_str ++ "save");
}

fn ensureConfigDirExists(config_path: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(config_path, .{});
    defer dir.close();

    try dir.makePath("zba");
}

fn romPath(result: *const clap.Result(clap.Help, &params, clap.parsers.default)) []const u8 {
    return switch (result.positionals.len) {
        1 => result.positionals[0],
        0 => exitln("ZBA requires a path to a GamePak ROM", .{}),
        else => exitln("ZBA received too many positional arguments.", .{}),
    };
}

fn exitln(comptime format: []const u8, args: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(format, args) catch {}; // Just exit already...
    stderr.writeByte('\n') catch {};
    std.os.exit(1);
}
