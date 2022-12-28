const std = @import("std");
const builtin = @import("builtin");
const Sdk = @import("lib/SDL.zig/Sdk.zig");

pub fn build(b: *std.build.Builder) void {
    // Minimum Zig Version
    const min_ver = std.SemanticVersion.parse("0.11.0-dev.987+a1d82352d") catch return; // https://github.com/ziglang/zig/commit/19056cb68
    if (builtin.zig_version.order(min_ver).compare(.lt)) {
        std.log.err("{s}", .{b.fmt("Zig v{} does not meet the minimum version requirement. (Zig v{})", .{ builtin.zig_version, min_ver })});
        std.os.exit(1);
    }

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zba", "src/main.zig");
    exe.setMainPkgPath("."); // Necessary so that src/main.zig can embed example.toml
    exe.setTarget(target);

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
    const sdk = Sdk.init(b);
    sdk.link(exe, .dynamic);
    exe.addPackage(sdk.getNativePackage("sdl2"));

    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
