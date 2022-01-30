const std = @import("std");
const SDL = @import("sdl2");

const emu = @import("emu.zig");
const Bus = @import("Bus.zig");
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Scheduler = @import("scheduler.zig").Scheduler;

const Timer = std.time.Timer;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;
const File = std.fs.File;

const window_scale = 3;
const gba_width = @import("ppu.zig").width;
const gba_height = @import("ppu.zig").height;
const buf_pitch = @import("ppu.zig").buf_pitch;

pub const enable_logging: bool = false;
const is_binary: bool = false;

pub fn main() anyerror!void {
    // Allocator for Emulator + CLI
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer std.debug.assert(!gpa.deinit());

    // Handle CLI Arguments
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const zba_args: []const []const u8 = args[1..];

    if (zba_args.len == 0) {
        std.log.err("Expected PATH to Gameboy Advance ROM as a CLI argument", .{});
        return;
    } else if (zba_args.len > 1) {
        std.log.err("Too many CLI arguments were provided", .{});
        return;
    }

    // Initialize Emulator
    var scheduler = Scheduler.init(alloc);
    defer scheduler.deinit();

    var bus = try Bus.init(alloc, &scheduler, zba_args[0]);
    defer bus.deinit();

    var cpu = Arm7tdmi.init(&scheduler, &bus);
    cpu.fastBoot();

    var log_file: ?File = undefined;
    if (enable_logging) {
        const file_name: []const u8 = if (is_binary) "zba.bin" else "zba.log";
        const file = try std.fs.cwd().createFile(file_name, .{ .read = true });
        cpu.useLogger(&file, is_binary);

        log_file = file;
    }
    defer if (log_file) |file| file.close();

    // Init Atomics
    var quit = Atomic(bool).init(false);

    // Create Emulator Thread
    const emu_thread = try Thread.spawn(.{}, emu.runEmuThread, .{ &quit, &scheduler, &cpu, &bus });
    defer emu_thread.join();

    // Initialize SDL
    const status = SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO);
    if (status < 0) sdlPanic();
    defer SDL.SDL_Quit();

    var window = SDL.SDL_CreateWindow(
        "ZBA",
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        gba_width * window_scale,
        gba_height * window_scale,
        SDL.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer SDL.SDL_DestroyWindow(window);

    var renderer = SDL.SDL_CreateRenderer(window, -1, SDL.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer SDL.SDL_DestroyRenderer(renderer);

    const texture = SDL.SDL_CreateTexture(renderer, SDL.SDL_PIXELFORMAT_BGR555, SDL.SDL_TEXTUREACCESS_STREAMING, 240, 160) orelse sdlPanic();
    defer SDL.SDL_DestroyTexture(texture);

    // Init FPS Timer
    // var timer = Timer.start() catch unreachable;
    // var title_buf: [0x30]u8 = [_]u8{0x00} ** 0x30;

    emu_loop: while (true) {
        var event: SDL.SDL_Event = undefined;
        _ = SDL.SDL_PollEvent(&event);

        switch (event.type) {
            SDL.SDL_QUIT => break :emu_loop,
            else => {},
        }

        // TODO: Make this Thread Safe
        const buf_ptr = bus.ppu.frame_buf.ptr;

        _ = SDL.SDL_UpdateTexture(texture, null, buf_ptr, buf_pitch);
        _ = SDL.SDL_RenderCopy(renderer, texture, null, null);
        SDL.SDL_RenderPresent(renderer);

        // const fps = std.time.ns_per_s / timer.lap();
        // const title = std.fmt.bufPrint(&title_buf, "ZBA FPS: {d}", .{fps}) catch unreachable;
        // SDL.SDL_SetWindowTitle(window, title.ptr);
    }

    quit.store(true, .Unordered); // Terminate Emulator Thread
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
