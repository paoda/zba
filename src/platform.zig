const std = @import("std");
const SDL = @import("sdl2");
const gl = @import("gl");
const emu = @import("core/emu.zig");
const config = @import("config.zig");

const Apu = @import("core/apu.zig").Apu;
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FpsTracker = @import("util.zig").FpsTracker;

const span = @import("util.zig").span;

const pitch = @import("core/ppu.zig").framebuf_pitch;
const gba_width = @import("core/ppu.zig").width;
const gba_height = @import("core/ppu.zig").height;

const default_title: []const u8 = "ZBA";

pub const Gui = struct {
    const Self = @This();
    const SDL_GLContext = *anyopaque; // SDL.SDL_GLContext is a ?*anyopaque
    const log = std.log.scoped(.Gui);

    // zig fmt: off
    const vertices: [32]f32 = [_]f32{
        // Positions        // Colours      // Texture Coords
         1.0, -1.0, 0.0,    1.0, 0.0, 0.0,  1.0, 1.0, // Top Right
         1.0,  1.0, 0.0,    0.0, 1.0, 0.0,  1.0, 0.0, // Bottom Right
        -1.0,  1.0, 0.0,    0.0, 0.0, 1.0,  0.0, 0.0, // Bottom Left
        -1.0, -1.0, 0.0,    1.0, 1.0, 0.0,  0.0, 1.0, // Top Left
    };

    const indices: [6]u32 = [_]u32{
        0, 1, 3, // First Triangle
        1, 2, 3, // Second Triangle
    };
    // zig fmt: on

    window: *SDL.SDL_Window,
    ctx: SDL_GLContext,
    title: []const u8,
    audio: Audio,

    program_id: gl.GLuint,

    pub fn init(title: *const [12]u8, apu: *Apu, width: i32, height: i32) Self {
        if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_PROFILE_MASK, SDL.SDL_GL_CONTEXT_PROFILE_CORE) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, 3) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, 3) < 0) panic();

        const win_scale = @intCast(c_int, config.config().host.win_scale);

        const window = SDL.SDL_CreateWindow(
            default_title.ptr,
            SDL.SDL_WINDOWPOS_CENTERED,
            SDL.SDL_WINDOWPOS_CENTERED,
            @as(c_int, width * win_scale),
            @as(c_int, height * win_scale),
            SDL.SDL_WINDOW_OPENGL | SDL.SDL_WINDOW_SHOWN,
        ) orelse panic();

        const ctx = SDL.SDL_GL_CreateContext(window) orelse panic();
        if (SDL.SDL_GL_MakeCurrent(window, ctx) < 0) panic();

        gl.load(ctx, Self.glGetProcAddress) catch @panic("gl.load failed");
        if (config.config().host.vsync) if (SDL.SDL_GL_SetSwapInterval(1) < 0) panic();

        const program_id = compileShaders();

        return Self{
            .window = window,
            .title = span(title),
            .ctx = ctx,
            .program_id = program_id,
            .audio = Audio.init(apu),
        };
    }

    fn compileShaders() gl.GLuint {
        // TODO: Panic on Shader Compiler Failure + Error Message
        const vert_shader = @embedFile("shader/pixelbuf.vert");
        const frag_shader = @embedFile("shader/pixelbuf.frag");

        const vs = gl.createShader(gl.VERTEX_SHADER);
        defer gl.deleteShader(vs);

        gl.shaderSource(vs, 1, &[_][*c]const u8{vert_shader}, 0);
        gl.compileShader(vs);

        const fs = gl.createShader(gl.FRAGMENT_SHADER);
        defer gl.deleteShader(fs);

        gl.shaderSource(fs, 1, &[_][*c]const u8{frag_shader}, 0);
        gl.compileShader(fs);

        const program = gl.createProgram();
        gl.attachShader(program, vs);
        gl.attachShader(program, fs);
        gl.linkProgram(program);

        return program;
    }

    // Returns the VAO ID since it's used in run()
    fn generateBuffers() [3]c_uint {
        var vao_id: c_uint = undefined;
        var vbo_id: c_uint = undefined;
        var ebo_id: c_uint = undefined;
        gl.genVertexArrays(1, &vao_id);
        gl.genBuffers(1, &vbo_id);
        gl.genBuffers(1, &ebo_id);

        gl.bindVertexArray(vao_id);

        gl.bindBuffer(gl.ARRAY_BUFFER, vbo_id);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo_id);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);

        // Position
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, 0)); // lmao
        gl.enableVertexAttribArray(0);
        // Colour
        gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, (3 * @sizeOf(f32))));
        gl.enableVertexAttribArray(1);
        // Texture Coord
        gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, (6 * @sizeOf(f32))));
        gl.enableVertexAttribArray(2);

        return .{ vao_id, vbo_id, ebo_id };
    }

    fn generateTexture(buf: []const u8) c_uint {
        var tex_id: c_uint = undefined;
        gl.genTextures(1, &tex_id);
        gl.bindTexture(gl.TEXTURE_2D, tex_id);

        // gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        // gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gba_width, gba_height, 0, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, buf.ptr);
        // gl.generateMipmap(gl.TEXTURE_2D); // TODO: Remove?

        return tex_id;
    }

    pub fn run(self: *Self, cpu: *Arm7tdmi, scheduler: *Scheduler) !void {
        var quit = std.atomic.Atomic(bool).init(false);
        var tracker = FpsTracker.init();

        const thread = try std.Thread.spawn(.{}, emu.run, .{ &quit, scheduler, cpu, &tracker });
        defer thread.join();

        var title_buf: [0x100]u8 = [_]u8{0} ** 0x100;

        const vao_id = Self.generateBuffers()[0];
        _ = Self.generateTexture(cpu.bus.ppu.framebuf.get(.Renderer));

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
                            SDL.SDLK_i => log.err("Sample Count: {}", .{@intCast(u32, SDL.SDL_AudioStreamAvailable(cpu.bus.apu.stream)) / (2 * @sizeOf(u16))}),
                            SDL.SDLK_j => log.err("Scheduler Capacity: {} | Scheduler Event Count: {}", .{ scheduler.queue.capacity(), scheduler.queue.count() }),
                            SDL.SDLK_k => {
                                // Dump IWRAM to file
                                log.info("PC: 0x{X:0>8}", .{cpu.r[15]});
                                log.info("LR: 0x{X:0>8}", .{cpu.r[14]});
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
            const framebuf = cpu.bus.ppu.framebuf.get(.Renderer);
            gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, gba_width, gba_height, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, framebuf.ptr);

            gl.useProgram(self.program_id);
            gl.bindVertexArray(vao_id);
            gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
            SDL.SDL_GL_SwapWindow(self.window);

            const dyn_title = std.fmt.bufPrint(&title_buf, "ZBA | {s} [Emu: {}fps] ", .{ self.title, tracker.value() }) catch unreachable;
            SDL.SDL_SetWindowTitle(self.window, dyn_title.ptr);
        }

        quit.store(true, .SeqCst); // Terminate Emulator Thread
    }

    pub fn deinit(self: *Self) void {
        self.audio.deinit();
        // TODO: Buffer deletions
        gl.deleteProgram(self.program_id);
        SDL.SDL_GL_DeleteContext(self.ctx);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
        self.* = undefined;
    }

    fn glGetProcAddress(ctx: SDL.SDL_GLContext, proc: [:0]const u8) ?*anyopaque {
        _ = ctx;
        return SDL.SDL_GL_GetProcAddress(@ptrCast([*c]const u8, proc));
    }
};

const Audio = struct {
    const Self = @This();
    const log = std.log.scoped(.PlatformAudio);
    const sample_rate = @import("core/apu.zig").host_sample_rate;

    device: SDL.SDL_AudioDeviceID,

    fn init(apu: *Apu) Self {
        var have: SDL.SDL_AudioSpec = undefined;
        var want: SDL.SDL_AudioSpec = std.mem.zeroes(SDL.SDL_AudioSpec);
        want.freq = sample_rate;
        want.format = SDL.AUDIO_U16;
        want.channels = 2;
        want.samples = 0x100;
        want.callback = Self.callback;
        want.userdata = apu;

        const device = SDL.SDL_OpenAudioDevice(null, 0, &want, &have, 0);
        if (device == 0) panic();

        SDL.SDL_PauseAudioDevice(device, 0); // Unpause Audio

        return .{ .device = device };
    }

    fn deinit(self: *Self) void {
        SDL.SDL_CloseAudioDevice(self.device);
        self.* = undefined;
    }

    export fn callback(userdata: ?*anyopaque, stream: [*c]u8, len: c_int) void {
        const apu = @ptrCast(*Apu, @alignCast(@alignOf(*Apu), userdata));

        // TODO: Find a better way to mute this
        if (!config.config().host.mute) {
            _ = SDL.SDL_AudioStreamGet(apu.stream, stream, len);
        } else {
            // FIXME: I don't think this hack to remove DC Offset is acceptable :thinking:
            std.mem.set(u8, stream[0..@intCast(usize, len)], 0x40);
        }

        // If we don't write anything, play silence otherwise garbage will be played
        // if (written == 0) std.mem.set(u8, stream[0..@intCast(usize, len)], 0x40);
    }
};

fn panic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
