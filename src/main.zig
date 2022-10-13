const std = @import("std");
const builtin = @import("builtin");
const known_folders = @import("known_folders");
const clap = @import("clap");

const config = @import("config.zig");

const Gui = @import("platform.zig").Gui;
const Bus = @import("core/Bus.zig");
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FilePaths = @import("util.zig").FilePaths;

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Cli);
const width = @import("core/ppu.zig").width;
const height = @import("core/ppu.zig").height;
pub const log_level = if (builtin.mode != .Debug) .info else std.log.default_level;

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

    // TODO: Make Error message not Linux Specific
    const data_path = try known_folders.getPath(allocator, .data) orelse exit("Unable to Determine XDG Data Path", .{});
    defer allocator.free(data_path);

    const config_path = try configFilePath(allocator, data_path);
    defer allocator.free(config_path);

    const save_path = try savePath(allocator, data_path);
    defer allocator.free(save_path);

    try config.load(allocator, config_path);

    // Handle CLI Input
    const result = try clap.parse(clap.Help, &params, clap.parsers.default, .{});
    defer result.deinit();

    const paths = try handleArguments(allocator, data_path, &result);
    defer if (paths.save) |path| allocator.free(path);

    const cpu_trace = config.config().debug.cpu_trace;
    const log_file: ?std.fs.File = if (cpu_trace) try std.fs.cwd().createFile("zba.log", .{}) else null;
    defer if (log_file) |file| file.close();

    // TODO: Take Emulator Init Code out of main.zig
    var scheduler = Scheduler.init(allocator);
    defer scheduler.deinit();

    var bus: Bus = undefined;
    var cpu = Arm7tdmi.init(&scheduler, &bus, log_file);
    if (paths.bios == null) cpu.fastBoot();

    try bus.init(allocator, &scheduler, &cpu, paths);
    defer bus.deinit();

    var gui = Gui.init(&bus.pak.title, &bus.apu, width, height);
    defer gui.deinit();

    try gui.run(&cpu, &scheduler);
}

pub fn handleArguments(allocator: Allocator, data_path: []const u8, result: *const clap.Result(clap.Help, &params, clap.parsers.default)) !FilePaths {
    const rom_path = romPath(result);
    log.info("ROM path: {s}", .{rom_path});

    const bios_path = result.args.bios;
    if (bios_path) |path| log.info("BIOS path: {s}", .{path}) else log.info("No BIOS provided", .{});

    const save_path = try savePath(allocator, data_path);
    log.info("Save path: {s}", .{save_path});

    return FilePaths{
        .rom = rom_path,
        .bios = bios_path,
        .save = save_path,
    };
}

fn configFilePath(allocator: Allocator, data_path: []const u8) ![]const u8 {
    const path = try std.fs.path.join(allocator, &[_][]const u8{ data_path, "zba", "config.toml" });

    // We try to create the file exclusively, meaning that we err out if the file already exists.
    // All we care about is a file being there so we can just ignore that error in particular and
    // continue down the happy pathj
    std.fs.accessAbsolute(path, .{}) catch {
        const file_handle = try std.fs.createFileAbsolute(path, .{});
        file_handle.close();
    };

    return path;
}

fn savePath(allocator: Allocator, data_path: []const u8) ![]const u8 {
    var dir = try std.fs.openDirAbsolute(data_path, .{});
    defer dir.close();

    // Will either make the path recursively, or just exit early since it already exists
    try dir.makePath("zba" ++ [_]u8{std.fs.path.sep} ++ "save");

    // FIXME: Do we have to allocate? :sad:
    return try std.fs.path.join(allocator, &[_][]const u8{ data_path, "zba", "save" });
}

fn romPath(result: *const clap.Result(clap.Help, &params, clap.parsers.default)) []const u8 {
    return switch (result.positionals.len) {
        1 => result.positionals[0],
        0 => exit("ZBA requires a path to a GamePak ROM\n", .{}),
        else => exit("ZBA received too many positional arguments. \n", .{}),
    };
}

fn exit(comptime format: []const u8, args: anytype) noreturn {
    const stderr = std.io.getStdErr().writer();
    stderr.print(format, args) catch {}; // Just exit already...
    std.os.exit(1);
}
