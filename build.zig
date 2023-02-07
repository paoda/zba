const std = @import("std");
const builtin = @import("builtin");
const Sdk = @import("lib/SDL.zig/Sdk.zig");

pub fn build(b: *std.build.Builder) void {
    // Minimum Zig Version
    const min_ver = std.SemanticVersion.parse("0.11.0-dev.1580+a5b34a61a") catch return; // https://github.com/ziglang/zig/commit/a5b34a61a
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
    exe.addAnonymousModule("known_folders", .{ .source_file = .{ .path = "lib/known-folders/known-folders.zig" } });

    // DateTime Library
    exe.addAnonymousModule("datetime", .{ .source_file = .{ .path = "lib/zig-datetime/src/main.zig" } });

    // Bitfield type from FlorenceOS: https://github.com/FlorenceOS/
    exe.addAnonymousModule("bitfield", .{ .source_file = .{ .path = "lib/util/bitfield.zig" } });

    // Argument Parsing Library
    exe.addAnonymousModule("clap", .{ .source_file = .{ .path = "lib/zig-clap/clap.zig" } });

    // TOML Library
    exe.addAnonymousModule("toml", .{ .source_file = .{ .path = "lib/zig-toml/src/toml.zig" } });

    // OpenGL 3.3 Bindings
    exe.addAnonymousModule("gl", .{ .source_file = .{ .path = "lib/gl.zig" } });

    // Zig SDL Bindings: https://github.com/MasterQ32/SDL.zig
    const sdk = Sdk.init(b, null);
    sdk.link(exe, .dynamic);
    exe.addModule("sdl2", sdk.getNativeModule());

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
