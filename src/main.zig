const std = @import("std");
const builtin = @import("builtin");
const SDL = @import("sdl2");
const clap = @import("clap");
const known_folders = @import("known_folders");

const emu = @import("emu.zig");
const Bus = @import("Bus.zig");
const Apu = @import("apu.zig").Apu;
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Scheduler = @import("scheduler.zig").Scheduler;
const EmulatorFps = @import("util.zig").EmulatorFps;

const Timer = std.time.Timer;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;
const File = std.fs.File;

const window_scale = 4;
const gba_width = @import("ppu.zig").width;
const gba_height = @import("ppu.zig").height;
const framebuf_pitch = @import("ppu.zig").framebuf_pitch;
const expected_rate = @import("emu.zig").frame_rate;

const sample_rate = @import("apu.zig").host_sample_rate;

pub const enable_logging: bool = false;
const is_binary: bool = false;
const log = std.log.scoped(.GUI);
pub const log_level = if (builtin.mode != .Debug) .info else std.log.default_level;

const asString = @import("util.zig").asString;

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
    const save_dir = try setupSavePath(alloc);
    defer if (save_dir) |path| alloc.free(path);
    log.info("Found save directory: {s}", .{save_dir});

    // Initialize SDL
    _ = initSdl2();
    defer SDL.SDL_Quit();

    // Initialize Emulator
    var scheduler = Scheduler.init(alloc);
    defer scheduler.deinit();

    const paths = .{ .bios = bios_path, .rom = rom_path, .save = save_dir };
    var cpu = try Arm7tdmi.init(alloc, &scheduler, paths);
    defer cpu.deinit();

    cpu.bus.attach(&cpu);
    // cpu.fastBoot();

    // Initialize SDL Audio
    const audio_dev = initAudio(&cpu.bus.apu);
    defer SDL.SDL_CloseAudioDevice(audio_dev);

    const log_file: ?File = if (enable_logging) blk: {
        const file = try std.fs.cwd().createFile(if (is_binary) "zba.bin" else "zba.log", .{});
        cpu.useLogger(&file, is_binary);
        break :blk file;
    } else null;
    defer if (log_file) |file| file.close();

    // Init Atomics
    var quit = Atomic(bool).init(false);
    var emu_rate = EmulatorFps.init();

    // Create Emulator Thread
    const emu_thread = try Thread.spawn(.{}, emu.run, .{ .LimitedFPS, &quit, &emu_rate, &scheduler, &cpu });
    defer emu_thread.join();

    var title_buf: [0x20]u8 = std.mem.zeroes([0x20]u8);
    const window_title = try std.fmt.bufPrint(&title_buf, "ZBA | {s}", .{asString(cpu.bus.pak.title)});

    const window = createWindow(window_title, gba_width, gba_height);
    defer SDL.SDL_DestroyWindow(window);

    const renderer = createRenderer(window);
    defer SDL.SDL_DestroyRenderer(renderer);

    const texture = createTexture(renderer, gba_width, gba_height);
    defer SDL.SDL_DestroyTexture(texture);

    // Init FPS Timer
    var dyn_title_buf: [0x100]u8 = [_]u8{0x00} ** 0x100;

    emu_loop: while (true) {
        var event: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&event) != 0) {
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
                        SDL.SDLK_i => std.debug.print("{} samples\n", .{@intCast(u32, SDL.SDL_AudioStreamAvailable(cpu.bus.apu.stream)) / (2 * @sizeOf(f32))}),
                        else => {},
                    }
                },
                else => {},
            }
        }

        // Emulator has an internal Double Buffer
        const buf_ptr = cpu.bus.ppu.framebuf.get(.Renderer).ptr;
        _ = SDL.SDL_UpdateTexture(texture, null, buf_ptr, framebuf_pitch);
        _ = SDL.SDL_RenderCopy(renderer, texture, null, null);
        SDL.SDL_RenderPresent(renderer);

        const dyn_title = std.fmt.bufPrint(&dyn_title_buf, "{s} [Emu: {}fps] ", .{ window_title, emu_rate.value() }) catch unreachable;
        SDL.SDL_SetWindowTitle(window, dyn_title.ptr);
    }

    quit.store(true, .SeqCst); // Terminate Emulator Thread
}

const CliError = error{
    InsufficientOptions,
    UnneededOptions,
};

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}

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

fn initSdl2() c_int {
    const status = SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO | SDL.SDL_INIT_GAMECONTROLLER);
    if (status < 0) sdlPanic();

    return status;
}

fn createWindow(title: []u8, width: c_int, height: c_int) *SDL.SDL_Window {
    return SDL.SDL_CreateWindow(
        title.ptr,
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        width * window_scale,
        height * window_scale,
        SDL.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
}

fn createRenderer(window: *SDL.SDL_Window) *SDL.SDL_Renderer {
    return SDL.SDL_CreateRenderer(window, -1, SDL.SDL_RENDERER_ACCELERATED | SDL.SDL_RENDERER_PRESENTVSYNC) orelse sdlPanic();
}

fn createTexture(renderer: *SDL.SDL_Renderer, width: c_int, height: c_int) *SDL.SDL_Texture {
    return SDL.SDL_CreateTexture(
        renderer,
        SDL.SDL_PIXELFORMAT_RGBA8888,
        SDL.SDL_TEXTUREACCESS_STREAMING,
        width,
        height,
    ) orelse sdlPanic();
}

fn initAudio(apu: *Apu) SDL.SDL_AudioDeviceID {
    var have: SDL.SDL_AudioSpec = undefined;
    var want: SDL.SDL_AudioSpec = .{
        .freq = sample_rate,
        .format = SDL.AUDIO_U16,
        .channels = 2,
        .samples = 0x100,
        .callback = audioCallback,
        .userdata = apu,
        .silence = undefined,
        .size = undefined,
        .padding = undefined,
    };

    const dev = SDL.SDL_OpenAudioDevice(null, 0, &want, &have, 0);
    if (dev == 0) sdlPanic();

    // Start Playback on the Audio device
    SDL.SDL_PauseAudioDevice(dev, 0);
    return dev;
}

// FIXME: Sometimes, we hear garbage upon program start. Why?
export fn audioCallback(userdata: ?*anyopaque, stream: [*c]u8, len: c_int) void {
    const apu = @ptrCast(*Apu, @alignCast(8, userdata));
    _ = SDL.SDL_AudioStreamGet(apu.stream, stream, len);
}
