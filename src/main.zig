const std = @import("std");
const SDL = @import("sdl2");
const clap = @import("clap");
const known_folders = @import("known_folders");

const emu = @import("emu.zig");
const Bus = @import("Bus.zig");
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Scheduler = @import("scheduler.zig").Scheduler;
const FpsAverage = @import("util.zig").FpsAverage;

const Timer = std.time.Timer;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;
const File = std.fs.File;

const window_scale = 3;
const gba_width = @import("ppu.zig").width;
const gba_height = @import("ppu.zig").height;
const framebuf_pitch = @import("ppu.zig").framebuf_pitch;
const expected_rate = @import("emu.zig").frame_rate;

pub const enable_logging: bool = false;
const is_binary: bool = false;
const log = std.log.scoped(.GUI);

const correctTitle = @import("util.zig").correctTitle;

pub fn main() anyerror!void {
    // Allocator for Emulator + CLI
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer std.debug.assert(!gpa.deinit());

    // CLI Arguments
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\-b, --bios <str>      Optional path to a GBA BIOS ROM.
        \\<str>                 Path to the GBA GamePak ROM
        \\
    );

    var res = try clap.parse(clap.Help, &params, clap.parsers.default, .{});
    defer res.deinit();

    const stderr = std.io.getStdErr();
    defer stderr.close();

    if (res.args.help) return clap.help(stderr.writer(), clap.Help, &params, .{});
    const bios_path: ?[]const u8 = if (res.args.bios) |p| p else null;

    const rom_path = switch (res.positionals.len) {
        1 => res.positionals[0],
        0 => {
            try stderr.writeAll("ZBA requires a positional path to a GamePak ROM.\n");
            return CliError.InsufficientOptions;
        },
        else => {
            try stderr.writeAll("ZBA received too many arguments.\n");
            return CliError.UnneededOptions;
        },
    };

    // Determine Save Directory
    const save_path = try setupSavePath(alloc);
    defer if (save_path) |path| alloc.free(path);
    log.info("Save Path: {s}", .{save_path});

    // Initialize SDL
    const status = SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO | SDL.SDL_INIT_GAMECONTROLLER);
    defer SDL.SDL_Quit();
    if (status < 0) sdlPanic();

    // Initialize SDL Audio
    var have: SDL.SDL_AudioSpec = undefined;
    var want = std.mem.zeroes(SDL.SDL_AudioSpec);
    want.freq = 32768;
    want.format = SDL.AUDIO_S8;
    want.channels = 2;
    want.samples = 0x200;
    want.callback = null;

    const audio_dev = SDL.SDL_OpenAudioDevice(null, 0, &want, &have, 0);
    defer SDL.SDL_CloseAudioDevice(audio_dev);
    if (audio_dev == 0) sdlPanic();

    // Start Playback on the Audio evice
    SDL.SDL_PauseAudioDevice(audio_dev, 0);

    // Initialize Emulator
    var scheduler = Scheduler.init(alloc);
    defer scheduler.deinit();

    const paths = .{ .bios = bios_path, .rom = rom_path, .save = save_path };
    var cpu = try Arm7tdmi.init(alloc, &scheduler, paths);
    defer cpu.deinit();

    cpu.bus.apu.attachAudioDevice(audio_dev);
    cpu.fastBoot();

    const log_file: ?File = if (enable_logging) blk: {
        const file = try std.fs.cwd().createFile(if (is_binary) "zba.bin" else "zba.log", .{});
        cpu.useLogger(&file, is_binary);
        break :blk file;
    } else null;
    defer if (log_file) |file| file.close();

    // Init Atomics
    var quit = Atomic(bool).init(false);
    var emu_rate = FpsAverage.init();

    // Create Emulator Thread
    const emu_thread = try Thread.spawn(.{}, emu.run, .{ .LimitedFPS, &quit, &emu_rate, &scheduler, &cpu });
    defer emu_thread.join();

    const title = correctTitle(cpu.bus.pak.title);

    var title_buf: [0x20]u8 = std.mem.zeroes([0x20]u8);
    const window_title = try std.fmt.bufPrint(&title_buf, "ZBA | {s}", .{title});

    var window = SDL.SDL_CreateWindow(
        window_title.ptr,
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        gba_width * window_scale,
        gba_height * window_scale,
        SDL.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer SDL.SDL_DestroyWindow(window);

    const renderer = SDL.SDL_CreateRenderer(window, -1, SDL.SDL_RENDERER_ACCELERATED | SDL.SDL_RENDERER_PRESENTVSYNC) orelse sdlPanic();
    defer SDL.SDL_DestroyRenderer(renderer);

    const texture = SDL.SDL_CreateTexture(renderer, SDL.SDL_PIXELFORMAT_RGBA8888, SDL.SDL_TEXTUREACCESS_STREAMING, 240, 160) orelse sdlPanic();
    defer SDL.SDL_DestroyTexture(texture);

    // Init FPS Timer
    var dyn_title_buf: [0x100]u8 = [_]u8{0x00} ** 0x100;

    emu_loop: while (true) {
        var event: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&event) != 0) {
            // Pause Emulation Thread during Input Writing

            switch (event.type) {
                SDL.SDL_QUIT => break :emu_loop,
                SDL.SDL_KEYDOWN => {
                    const io = &cpu.bus.io;
                    const key_code = event.key.keysym.sym;

                    switch (key_code) {
                        SDL.SDLK_UP => io.keyinput.up.unset(),
                        SDL.SDLK_DOWN => io.keyinput.down.unset(),
                        SDL.SDLK_LEFT => io.keyinput.left.unset(),
                        SDL.SDLK_RIGHT => io.keyinput.right.unset(),
                        SDL.SDLK_x => io.keyinput.a.unset(),
                        SDL.SDLK_z => io.keyinput.b.unset(),
                        SDL.SDLK_a => io.keyinput.shoulder_l.unset(),
                        SDL.SDLK_s => io.keyinput.shoulder_r.unset(),
                        SDL.SDLK_RETURN => io.keyinput.start.unset(),
                        SDL.SDLK_RSHIFT => io.keyinput.select.unset(),
                        else => {},
                    }
                },
                SDL.SDL_KEYUP => {
                    const io = &cpu.bus.io;
                    const key_code = event.key.keysym.sym;

                    switch (key_code) {
                        SDL.SDLK_UP => io.keyinput.up.set(),
                        SDL.SDLK_DOWN => io.keyinput.down.set(),
                        SDL.SDLK_LEFT => io.keyinput.left.set(),
                        SDL.SDLK_RIGHT => io.keyinput.right.set(),
                        SDL.SDLK_x => io.keyinput.a.set(),
                        SDL.SDLK_z => io.keyinput.b.set(),
                        SDL.SDLK_a => io.keyinput.shoulder_l.set(),
                        SDL.SDLK_s => io.keyinput.shoulder_r.set(),
                        SDL.SDLK_RETURN => io.keyinput.start.set(),
                        SDL.SDLK_RSHIFT => io.keyinput.select.set(),
                        else => {},
                    }
                },
                else => {},
            }
        }

        // FIXME: Is it OK just to copy the Emulator's Frame Buffer to SDL?
        const buf_ptr = cpu.bus.ppu.framebuf.ptr;
        _ = SDL.SDL_UpdateTexture(texture, null, buf_ptr, framebuf_pitch);
        _ = SDL.SDL_RenderCopy(renderer, texture, null, null);
        SDL.SDL_RenderPresent(renderer);

        const actual = emu_rate.calc();
        const dyn_title = std.fmt.bufPrint(&dyn_title_buf, "{s} [Emu: {d:0>3.2}fps, {d:0>3.2}%] ", .{ window_title, actual, actual * 100 / expected_rate }) catch unreachable;
        SDL.SDL_SetWindowTitle(window, dyn_title.ptr);
    }

    quit.store(true, .Unordered); // Terminate Emulator Thread
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}

const CliError = error{
    InsufficientOptions,
    UnneededOptions,
};

// FIXME: Superfluous allocations?
fn setupSavePath(alloc: std.mem.Allocator) !?[]const u8 {
    const save_subpath = try std.fs.path.join(alloc, &[_][]const u8{ "zba", "save" });
    defer alloc.free(save_subpath);

    const maybe_data_path = try known_folders.getPath(alloc, .data);
    defer if (maybe_data_path) |path| alloc.free(path);

    const save_path = if (maybe_data_path) |base| try std.fs.path.join(alloc, &[_][]const u8{ base, save_subpath }) else null;

    if (save_path) |_| {
        // If we've determined what our save path should be, ensure the prereq directories
        // are present so that we can successfully write to the path when necessary
        const maybe_data_dir = try known_folders.open(alloc, .data, .{});
        if (maybe_data_dir) |data_dir| try data_dir.makePath(save_subpath);
    }

    return save_path;
}
