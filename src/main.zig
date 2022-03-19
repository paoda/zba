const std = @import("std");
const SDL = @import("sdl2");
const clap = @import("clap");

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

pub const enable_logging: bool = false;
const is_binary: bool = false;

pub fn main() anyerror!void {
    // Allocator for Emulator + CLI
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer std.debug.assert(!gpa.deinit());

    // Parse CLI Arguments
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-h, --help         Display this help and exit.     ") catch unreachable,
        clap.parseParam("-b, --bios <PATH>  Optional Path to GBA BIOS ROM.  ") catch unreachable,
        clap.parseParam("<PATH>             Path to GBA GamePak ROM         ") catch unreachable,
    };

    var args = try clap.parse(clap.Help, &params, .{});
    defer args.deinit();

    if (args.flag("--help")) return clap.help(std.io.getStdErr().writer(), &params);

    const maybe_bios: ?[]const u8 = if (args.option("--bios")) |p| p else null;

    const positionals = args.positionals();
    const stderr = std.io.getStdErr();
    defer stderr.close();

    const rom_path = switch (positionals.len) {
        1 => positionals[0],
        0 => {
            try stderr.writeAll("ZBA requires a positional path to a GamePak ROM.\n");
            return CliError.InsufficientOptions;
        },
        else => {
            try stderr.writeAll("ZBA received too many arguments.\n");
            return CliError.UnneededOptions;
        },
    };

    // Initialize Emulator
    var scheduler = Scheduler.init(alloc);
    defer scheduler.deinit();

    var bus = try Bus.init(alloc, &scheduler, rom_path, maybe_bios);
    defer bus.deinit();

    var cpu = Arm7tdmi.init(&scheduler, &bus);
    cpu.fastBoot();

    const log_file: ?File = if (enable_logging) blk: {
        const file = try std.fs.cwd().createFile(if (is_binary) "zba.bin" else "zba.log", .{});
        cpu.useLogger(&file, is_binary);
        break :blk file;
    } else null;
    defer if (log_file) |file| file.close();

    // Init Atomics
    var quit = Atomic(bool).init(false);
    var emu_fps = FpsAverage.init();

    // Create Emulator Thread
    const emu_thread = try Thread.spawn(.{}, emu.run, .{ .UnlimitedFPS, &quit, &emu_fps, &scheduler, &cpu, &bus });
    defer emu_thread.join();

    // Initialize SDL
    const status = SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO | SDL.SDL_INIT_GAMECONTROLLER);
    if (status < 0) sdlPanic();
    defer SDL.SDL_Quit();

    var title_buf: [0x20]u8 = std.mem.zeroes([0x20]u8);
    var title = try std.fmt.bufPrint(&title_buf, "ZBA | {s}", .{bus.pak.title});
    correctTitleSlice(&title);

    var window = SDL.SDL_CreateWindow(
        title.ptr,
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
                    const key_code = event.key.keysym.sym;

                    switch (key_code) {
                        SDL.SDLK_UP => bus.io.keyinput.up.unset(),
                        SDL.SDLK_DOWN => bus.io.keyinput.down.unset(),
                        SDL.SDLK_LEFT => bus.io.keyinput.left.unset(),
                        SDL.SDLK_RIGHT => bus.io.keyinput.right.unset(),
                        SDL.SDLK_x => bus.io.keyinput.a.unset(),
                        SDL.SDLK_z => bus.io.keyinput.b.unset(),
                        SDL.SDLK_a => bus.io.keyinput.shoulder_l.unset(),
                        SDL.SDLK_s => bus.io.keyinput.shoulder_r.unset(),
                        SDL.SDLK_RETURN => bus.io.keyinput.start.unset(),
                        SDL.SDLK_RSHIFT => bus.io.keyinput.select.unset(),
                        else => {},
                    }
                },
                SDL.SDL_KEYUP => {
                    const key_code = event.key.keysym.sym;

                    switch (key_code) {
                        SDL.SDLK_UP => bus.io.keyinput.up.set(),
                        SDL.SDLK_DOWN => bus.io.keyinput.down.set(),
                        SDL.SDLK_LEFT => bus.io.keyinput.left.set(),
                        SDL.SDLK_RIGHT => bus.io.keyinput.right.set(),
                        SDL.SDLK_x => bus.io.keyinput.a.set(),
                        SDL.SDLK_z => bus.io.keyinput.b.set(),
                        SDL.SDLK_a => bus.io.keyinput.shoulder_l.set(),
                        SDL.SDLK_s => bus.io.keyinput.shoulder_r.set(),
                        SDL.SDLK_RETURN => bus.io.keyinput.start.set(),
                        SDL.SDLK_RSHIFT => bus.io.keyinput.select.set(),
                        else => {},
                    }
                },
                else => {},
            }
        }

        // FIXME: Is it OK just to copy the Emulator's Frame Buffer to SDL?
        const buf_ptr = bus.ppu.framebuf.ptr;
        _ = SDL.SDL_UpdateTexture(texture, null, buf_ptr, framebuf_pitch);
        _ = SDL.SDL_RenderCopy(renderer, texture, null, null);
        SDL.SDL_RenderPresent(renderer);

        const avg = emu_fps.calc();
        const dyn_title = std.fmt.bufPrint(&dyn_title_buf, "{s} [Emu: {d:0>3}fps, {d:0>3}%] ", .{ title, avg, (avg * 100 / 59) }) catch unreachable;
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

/// The slice considers some null values to be a part of the string
/// so change the length of the slice so that isn't the case
// FIXME: This is awful and bad
fn correctTitleSlice(title: *[]u8) void {
    for (title.*) |char, i| {
        if (char == 0) {
            title.len = i;
            break;
        }
    }
}
