const std = @import("std");
const builtin = @import("builtin");

const Sdk = @import("lib/SDL.zig/Sdk.zig");
const gdbstub = @import("lib/zba-gdbstub/build.zig");
const zgui = @import("lib/zgui/build.zig");
const nfd = @import("lib/nfd-zig/build.zig");

pub fn build(b: *std.Build) void {
    // Minimum Zig Version
    const min_ver = std.SemanticVersion.parse("0.11.0-dev.2168+322ace70f") catch return; // https://github.com/ziglang/zig/commit/322ace70f
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
    exe.addAnonymousModule("bitfield", .{ .source_file = .{ .path = "lib/bitfield.zig" } });

    // Argument Parsing Library
    exe.addAnonymousModule("clap", .{ .source_file = .{ .path = "lib/zig-clap/clap.zig" } });

    // TOML Library
    exe.addAnonymousModule("toml", .{ .source_file = .{ .path = "lib/zig-toml/src/toml.zig" } });

    // OpenGL 3.3 Bindings
    exe.addAnonymousModule("gl", .{ .source_file = .{ .path = "lib/gl.zig" } });

    // ZBA utility code
    exe.addAnonymousModule("zba-util", .{ .source_file = .{ .path = "lib/zba-util/src/lib.zig" } });

    // gdbstub
    exe.addModule("gdbstub", gdbstub.getModule(b));

    // NativeFileDialog(ue) Bindings
    exe.linkLibrary(nfd.makeLib(b, target, optimize));
    exe.addModule("nfd", nfd.getModule(b));

    // Zig SDL Bindings: https://github.com/MasterQ32/SDL.zig
    const sdk = Sdk.init(b, null);
    sdk.link(exe, .dynamic);
    exe.addModule("sdl2", sdk.getNativeModule());

    // Dear ImGui bindings

    // .shared option should stay in sync with SDL.zig call above where true == .dynamic, and false == .static
    const zgui_pkg = zgui.package(b, target, optimize, .{ .options = .{ .backend = .sdl2_opengl3, .shared = true } });
    zgui_pkg.link(exe);

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
