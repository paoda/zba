const std = @import("std");
const SDL = @import("sdl2");
const Self = @This();

const Apu = @import("core/apu.zig").Apu;
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FpsTracker = @import("core/util.zig").FpsTracker;

const pitch = @import("core/ppu.zig").framebuf_pitch;
const scale = @import("core/emu.zig").win_scale;

const emu = @import("core/emu.zig");
const log = std.log.scoped(.GUI);

const default_title: []const u8 = "ZBA";

window: *SDL.SDL_Window,
base_title: [12]u8,
renderer: *SDL.SDL_Renderer,
texture: *SDL.SDL_Texture,
audio: ?Audio,

pub fn init(title: [12]u8, width: i32, height: i32) Self {
    const ret = SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO | SDL.SDL_INIT_GAMECONTROLLER);
    if (ret < 0) panic();

    const window = SDL.SDL_CreateWindow(
        default_title.ptr,
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        @as(c_int, width * scale),
        @as(c_int, height * scale),
        SDL.SDL_WINDOW_SHOWN,
    ) orelse panic();

    const renderer = SDL.SDL_CreateRenderer(window, -1, SDL.SDL_RENDERER_ACCELERATED | SDL.SDL_RENDERER_PRESENTVSYNC) orelse panic();

    const texture = SDL.SDL_CreateTexture(
        renderer,
        SDL.SDL_PIXELFORMAT_RGBA8888,
        SDL.SDL_TEXTUREACCESS_STREAMING,
        @as(c_int, width),
        @as(c_int, height),
    ) orelse panic();

    return Self{
        .window = window,
        .base_title = title,
        .renderer = renderer,
        .texture = texture,
        .audio = null,
    };
}

pub fn run(self: *Self, arm7tdmi: *Arm7tdmi, scheduler: *Scheduler) !void {
    var quit = std.atomic.Atomic(bool).init(false);
    var frame_rate = FpsTracker.init();

    const thread = try std.Thread.spawn(.{}, emu.run, .{ &quit, &frame_rate, scheduler, arm7tdmi });
    defer thread.join();

    var title_buf: [0x100]u8 = [_]u8{0} ** 0x100;

    emu_loop: while (true) {
        var event: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                SDL.SDL_QUIT => break :emu_loop,
                SDL.SDL_KEYDOWN => {
                    const io = &arm7tdmi.bus.io;
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
                    const io = &arm7tdmi.bus.io;
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
                        SDL.SDLK_i => log.err("Sample Count: {}", .{@intCast(u32, SDL.SDL_AudioStreamAvailable(arm7tdmi.bus.apu.stream)) / (2 * @sizeOf(u16))}),
                        SDL.SDLK_j => log.err("Scheduler Capacity: {} | Scheduler Event Count: {}", .{ scheduler.queue.capacity(), scheduler.queue.count() }),
                        SDL.SDLK_k => {
                            // Dump IWRAM to file
                            log.info("PC: 0x{X:0>8}", .{arm7tdmi.r[15]});
                            log.info("LR: 0x{X:0>8}", .{arm7tdmi.r[14]});
                            // const iwram_file = try std.fs.cwd().createFile("iwram.bin", .{});
                            // defer iwram_file.close();

                            // try iwram_file.writeAll(cpu.bus.iwram.buf);
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        // Emulator has an internal Double Buffer
        const framebuf = arm7tdmi.bus.ppu.framebuf.get(.Renderer);
        _ = SDL.SDL_UpdateTexture(self.texture, null, framebuf.ptr, pitch);
        _ = SDL.SDL_RenderCopy(self.renderer, self.texture, null, null);
        SDL.SDL_RenderPresent(self.renderer);

        const title = std.fmt.bufPrint(&title_buf, "ZBA | {s} [Emu: {}fps] ", .{ self.base_title, frame_rate.value() }) catch unreachable;
        SDL.SDL_SetWindowTitle(self.window, title.ptr);
    }

    quit.store(true, .SeqCst); // Terminate Emulator Thread
}

pub fn initAudio(self: *Self, apu: *Apu) void {
    self.audio = Audio.init(apu);
    self.audio.?.play();
}

pub fn deinit(self: *Self) void {
    if (self.audio) |*aud| aud.deinit();
    SDL.SDL_DestroyTexture(self.texture);
    SDL.SDL_DestroyRenderer(self.renderer);
    SDL.SDL_DestroyWindow(self.window);
    SDL.SDL_Quit();
    self.* = undefined;
}

const Audio = struct {
    const This = @This();
    const sample_rate = @import("core/apu.zig").host_sample_rate;

    device: SDL.SDL_AudioDeviceID,

    fn init(apu: *Apu) This {
        var have: SDL.SDL_AudioSpec = undefined;
        var want: SDL.SDL_AudioSpec = std.mem.zeroes(SDL.SDL_AudioSpec);
        want.freq = sample_rate;
        want.format = SDL.AUDIO_U16;
        want.channels = 2;
        want.samples = 0x100;
        want.callback = This.callback;
        want.userdata = apu;

        const device = SDL.SDL_OpenAudioDevice(null, 0, &want, &have, 0);
        if (device == 0) panic();

        return .{
            .device = device,
        };
    }

    fn deinit(self: *This) void {
        SDL.SDL_CloseAudioDevice(self.device);
        self.* = undefined;
    }

    pub fn play(this: *This) void {
        SDL.SDL_PauseAudioDevice(this.device, 0);
    }

    export fn callback(userdata: ?*anyopaque, stream: [*c]u8, len: c_int) void {
        const apu = @ptrCast(*Apu, @alignCast(@alignOf(*Apu), userdata));
        const written = SDL.SDL_AudioStreamGet(apu.stream, stream, len);

        // If we don't write anything, play silence otherwise garbage will be played
        // FIXME: I don't think this hack to remove DC Offset is acceptable :thinking:
        if (written == 0) std.mem.set(u8, stream[0..@intCast(usize, len)], 0x40);
    }
};

fn panic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
