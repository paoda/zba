const std = @import("std");
const toml = @import("toml");

const Allocator = std.mem.Allocator;

const log = std.log.scoped(.Config);
var state: Config = .{};

const Config = struct {
    host: Host = .{},
    guest: Guest = .{},
    debug: Debug = .{},

    /// Settings related to the Computer the Emulator is being run on
    const Host = struct {
        /// Using Nearest-Neighbor, multiply the resolution of the GBA Window
        win_scale: i64 = 3,
        /// Enable Vsync
        ///
        /// Note: This does not affect whether Emulation is synced to 59Hz
        vsync: bool = true,
        /// Mute ZBA
        mute: bool = false,
    };

    // Settings realted to the emulation itself
    const Guest = struct {
        /// Whether Emulation thread to sync to Audio Callbacks
        audio_sync: bool = true,
        /// Whether Emulation thread should sync to 59Hz
        video_sync: bool = true,
        /// Whether RTC I/O should always be enabled
        force_rtc: bool = false,
        /// Skip BIOS
        skip_bios: bool = false,
    };

    /// Settings related to debugging ZBA
    const Debug = struct {
        /// Enable CPU Trace logs
        cpu_trace: bool = false,
        /// If false and ZBA is built in debug mode, ZBA will panic on unhandled I/O
        unhandled_io: bool = true,
    };
};

pub fn config() *const Config {
    return &state;
}

/// Reads a config file and then loads it into the global state
pub fn load(allocator: Allocator, config_path: []const u8) !void {
    var dir = try std.fs.openDirAbsolute(config_path, .{});
    defer dir.close();

    const sub_path = "zba" ++ std.fs.path.sep_str ++ "config.toml";

    var file = try dir.openFile(sub_path, .{});
    defer file.close();

    {
        const path = try std.fs.path.join(allocator, &.{ config_path, sub_path });
        defer allocator.free(path);

        log.info("loaded from {s}", .{path});
    }

    const contents = try file.readToEndAlloc(allocator, try file.getEndPos());
    defer allocator.free(contents);

    var parser = toml.Parser(Config).init(allocator);
    defer parser.deinit();

    const parsed = try parser.parseString(contents);
    defer parsed.deinit();

    state = parsed.value; // FIXME: should copy the struct to state
}
