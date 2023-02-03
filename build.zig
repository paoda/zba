const std = @import("std");
const builtin = @import("builtin");
const Sdk = @import("lib/SDL.zig/Sdk.zig");

pub fn build(b: *std.build.Builder) void {
    // Minimum Zig Version
    const min_ver = std.SemanticVersion.parse("0.11.0-dev.1557+03cdb4fb5") catch return; // https://github.com/ziglang/zig/commit/03cdb4fb5
    if (builtin.zig_version.order(min_ver).compare(.lt)) {
        std.log.err("{s}", .{b.fmt("Zig v{} does not meet the minimum version requirement. (Zig v{})", .{ builtin.zig_version, min_ver })});
        std.os.exit(1);
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zba",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.setMainPkgPath("."); // Necessary so that src/main.zig can embed example.toml

    // Known Folders (%APPDATA%, XDG, etc.)
    exe.addPackagePath("known_folders", "lib/known-folders/known-folders.zig");

    // DateTime Library
    exe.addPackagePath("datetime", "lib/zig-datetime/src/main.zig");

    // Bitfield type from FlorenceOS: https://github.com/FlorenceOS/
    // exe.addPackage(.{ .name = "bitfield", .path = .{ .path = "lib/util/bitfield.zig" } });
    exe.addPackagePath("bitfield", "lib/util/bitfield.zig");

    // Argument Parsing Library
    exe.addPackagePath("clap", "lib/zig-clap/clap.zig");

    // TOML Library
    exe.addPackagePath("toml", "lib/zig-toml/src/toml.zig");

    // OpenGL 3.3 Bindings
    exe.addPackagePath("gl", "lib/gl.zig");

    // Zig SDL Bindings: https://github.com/MasterQ32/SDL.zig
    const sdk = Sdk.init(b, null);
    sdk.link(exe, .dynamic);
    exe.addPackage(sdk.getNativePackage("sdl2"));

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
