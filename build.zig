const std = @import("std");
const builtin = @import("builtin");

const Sdk = @import("lib/SDL.zig/build.zig");
const zgui = @import("lib/zgui/build.zig");

const SemVer = std.SemanticVersion;

const expected_zig_version = "0.12.0-dev.2063+804cee3b9";

pub fn build(b: *std.Build) void {
    const attempted_zig_version = builtin.zig_version;
    if (comptime attempted_zig_version.order(SemVer.parse(expected_zig_version) catch unreachable) != .eq) {
        @compileError("ZBA must be built with Zig v" ++ expected_zig_version ++ ".");
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zba",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("known_folders", b.dependency("known-folders", .{}).module("known-folders")); // https://github.com/ziglibs/known-folders
    exe.root_module.addImport("datetime", b.dependency("zig-datetime", .{}).module("zig-datetime")); // https://github.com/frmdstryr/zig-datetime
    exe.root_module.addImport("clap", b.dependency("zig-clap", .{}).module("clap")); // https://github.com/Hejsil/zig-clap
    exe.root_module.addImport("zba-util", b.dependency("zba-util", .{}).module("zba-util")); // https://git.musuka.dev/paoda/zba-util
    exe.root_module.addImport("tomlz", b.dependency("tomlz", .{}).module("tomlz")); // https://github.com/mattyhall/tomlz
    exe.root_module.addImport("arm32", b.dependency("arm32", .{}).module("arm32")); // https://git.musuka.dev/paoda/arm32
    exe.root_module.addImport("gdbstub", b.dependency("zba-gdbstub", .{}).module("gdbstub")); // https://git.musuka.dev/paoda/gdbstub
    exe.root_module.addImport("nfd", b.dependency("nfd", .{}).module("nfd")); // https://github.com/fabioarnold/nfd-zig

    exe.root_module.addAnonymousImport("bitfield", .{ .root_source_file = .{ .path = "lib/bitfield.zig" } }); // https://github.com/FlorenceOS/
    exe.root_module.addAnonymousImport("gl", .{ .root_source_file = .{ .path = "lib/gl.zig" } }); // https://github.com/MasterQ32/zig-opengl
    exe.root_module.addAnonymousImport("example.toml", .{ .root_source_file = .{ .path = "example.toml" } });

    // https://github.com/MasterQ32/SDL.zig
    const sdk = Sdk.init(b, null);
    sdk.link(exe, .static);
    exe.root_module.addImport("sdl2", sdk.getNativeModule());

    // https://git.musuka.dev/paoda/zgui
    // .shared option should stay in sync with SDL.zig call above where true == .dynamic, and false == .static
    const zgui_pkg = zgui.package(b, target, optimize, .{ .options = .{ .backend = .sdl2_opengl3 } });
    zgui_pkg.link(exe);
    sdk.link(zgui_pkg.zgui_c_cpp, .static);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

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
