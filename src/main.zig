const std = @import("std");
const SDL = @import("sdl2");

const emu = @import("emu.zig");
const Bus = @import("Bus.zig");
const Arm7tdmi = @import("cpu.zig").Arm7tdmi;
const Scheduler = @import("scheduler.zig").Scheduler;

pub fn main() anyerror!void {
    // Allocator for Emulator + CLI Aruments
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
    cpu.skipBios();

    // Initialize SDL
    const status = SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO);
    if (status < 0) sdlPanic();
    defer SDL.SDL_Quit();

    var window = SDL.SDL_CreateWindow(
        "Gameboy Advance Emulator",
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        240 * 3,
        160 * 3,
        SDL.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer SDL.SDL_DestroyWindow(window);

    var renderer = SDL.SDL_CreateRenderer(window, -1, SDL.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer SDL.SDL_DestroyRenderer(renderer);

    const texture = SDL.SDL_CreateTexture(renderer, SDL.SDL_PIXELFORMAT_BGR555, SDL.SDL_TEXTUREACCESS_STREAMING, 240, 160) orelse sdlPanic();
    defer SDL.SDL_DestroyTexture(texture);

    const buf_pitch = 240 * @sizeOf(u16);
    const buf_len = buf_pitch * 160;
    var white: [buf_len]u8 = [_]u8{ 0xFF, 0x7F } ** (buf_len / 2);

    var white_heap = try alloc.alloc(u8, buf_len);
    for (white) |b, i| white_heap[i] = b;
    defer alloc.free(white_heap);

    emu_loop: while (true) {
        emu.runFrame(&scheduler, &cpu, &bus);

        var event: SDL.SDL_Event = undefined;
        _ = SDL.SDL_PollEvent(&event);

        switch (event.type) {
            SDL.SDL_QUIT => break :emu_loop,
            else => {},
        }

        _ = SDL.SDL_UpdateTexture(texture, null, &white_heap, buf_pitch);
        _ = SDL.SDL_RenderCopy(renderer, texture, null, null);
        SDL.SDL_RenderPresent(renderer);
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
