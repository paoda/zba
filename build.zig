const std = @import("std");
const builtin = @import("builtin");

const Sdk = @import("lib/SDL.zig/Sdk.zig");
const zgui = @import("lib/zgui/build.zig");
const gdbstub = @import("lib/zba-gdbstub/build.zig");

pub fn build(b: *std.Build) void {
    // Minimum Zig Version
    const min_ver = std.SemanticVersion.parse("0.11.0") catch return; // https://github.com/ziglang/zig/tree/0.11.0
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
    exe.main_pkg_path = .{ .path = "." }; // Necessary so that src/main.zig can embed example.toml

    exe.addModule("known_folders", b.dependency("known-folders", .{}).module("known-folders")); // https://github.com/ziglibs/known-folders
    exe.addModule("datetime", b.dependency("zig-datetime", .{}).module("zig-datetime")); // https://github.com/frmdstryr/zig-datetime
    exe.addModule("clap", b.dependency("zig-clap", .{}).module("clap")); // https://github.com/Hejsil/zig-clap
    exe.addModule("zba-util", b.dependency("zba-util", .{}).module("zba-util")); // https://git.musuka.dev/paoda/zba-util
    exe.addModule("tomlz", b.dependency("tomlz", .{}).module("tomlz")); // https://github.com/mattyhall/tomlz
    exe.addModule("arm32", b.dependency("arm32", .{}).module("arm32")); // https://git.musuka.dev/paoda/arm32

    exe.addModule("gdbstub", gdbstub.module(b)); // https://git.musuka.dev/paoda/gdbstub

    // https://github.com/fabioarnold/nfd-zig
    const nfd_dep = b.dependency("nfd", .{ .target = target, .optimize = optimize });
    exe.linkLibrary(nfd_dep.artifact("nfd"));
    exe.addModule("nfd", nfd_dep.module("nfd"));

    // https://github.com/MasterQ32/SDL.zig
    const sdk = Sdk.init(b, null);
    sdk.link(exe, .dynamic);
    exe.addModule("sdl2", sdk.getNativeModule());

    // https://git.musuka.dev/paoda/zgui
    // .shared option should stay in sync with SDL.zig call above where true == .dynamic, and false == .static
    const zgui_pkg = zgui.package(b, target, optimize, .{ .options = .{ .backend = .sdl2_opengl3, .shared = true } });
    zgui_pkg.link(exe);

    exe.addAnonymousModule("bitfield", .{ .source_file = .{ .path = "lib/bitfield.zig" } }); // https://github.com/FlorenceOS/
    exe.addAnonymousModule("gl", .{ .source_file = .{ .path = "lib/gl.zig" } }); // https://github.com/MasterQ32/zig-opengl

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
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
