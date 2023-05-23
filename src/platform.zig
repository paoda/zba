const std = @import("std");
const SDL = @import("sdl2");
const gl = @import("gl");
const zgui = @import("zgui");

const emu = @import("core/emu.zig");
const config = @import("config.zig");
const imgui = @import("imgui.zig");

const Apu = @import("core/apu.zig").Apu;
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FpsTracker = @import("util.zig").FpsTracker;
const TwoWayChannel = @import("zba-util").TwoWayChannel;

const gba_width = @import("core/ppu.zig").width;
const gba_height = @import("core/ppu.zig").height;

const GLuint = gl.GLuint;
const GLsizei = gl.GLsizei;
const SDL_GLContext = *anyopaque;
const Allocator = std.mem.Allocator;

pub const Dimensions = struct { width: u32, height: u32 };
const default_dim: Dimensions = .{ .width = 1280, .height = 720 };

pub const sample_rate = 1 << 15;
pub const sample_format = SDL.AUDIO_U16;

const window_title = "ZBA";

pub const Gui = struct {
    const Self = @This();
    const log = std.log.scoped(.Gui);

    window: *SDL.SDL_Window,
    ctx: SDL_GLContext,
    audio: Audio,

    state: imgui.State,
    allocator: Allocator,

    pub fn init(allocator: Allocator, apu: *Apu, title_opt: ?*const [12]u8) !Self {
        if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_PROFILE_MASK, SDL.SDL_GL_CONTEXT_PROFILE_CORE) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, 3) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, 3) < 0) panic();

        const window = SDL.SDL_CreateWindow(
            window_title,
            SDL.SDL_WINDOWPOS_CENTERED,
            SDL.SDL_WINDOWPOS_CENTERED,
            default_dim.width,
            default_dim.height,
            SDL.SDL_WINDOW_OPENGL | SDL.SDL_WINDOW_SHOWN | SDL.SDL_WINDOW_RESIZABLE,
        ) orelse panic();

        const ctx = SDL.SDL_GL_CreateContext(window) orelse panic();
        if (SDL.SDL_GL_MakeCurrent(window, ctx) < 0) panic();

        gl.load(ctx, Self.glGetProcAddress) catch {};
        if (SDL.SDL_GL_SetSwapInterval(@boolToInt(config.config().host.vsync)) < 0) panic();

        zgui.init(allocator);
        zgui.plot.init();
        zgui.backend.init(window, ctx, "#version 330 core");

        // zgui.io.setIniFilename(null);

        return Self{
            .window = window,
            .ctx = ctx,
            .audio = Audio.init(apu),

            .allocator = allocator,
            .state = try imgui.State.init(allocator, title_opt),
        };
    }

    pub fn deinit(self: *Self) void {
        self.audio.deinit();
        self.state.deinit(self.allocator);

        zgui.backend.deinit();
        zgui.plot.deinit();
        zgui.deinit();

        SDL.SDL_GL_DeleteContext(self.ctx);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();

        self.* = undefined;
    }

    const RunOptions = struct {
        channel: *TwoWayChannel,
        tracker: ?*FpsTracker = null,
        cpu: *Arm7tdmi,
        scheduler: *Scheduler,
    };

    const RunMode = enum { Standard, Debug };

    pub fn run(self: *Self, comptime mode: RunMode, opt: RunOptions) !void {
        const cpu = opt.cpu;
        const tracker = opt.tracker;
        const channel = opt.channel;

        const objects = opengl_impl.createObjects();
        defer gl.deleteBuffers(3, @as(*const [3]GLuint, &.{ objects.vao, objects.vbo, objects.ebo }));

        const emu_tex = opengl_impl.createScreenTexture(cpu.bus.ppu.framebuf.get(.Renderer));
        const out_tex = opengl_impl.createOutputTexture();
        defer gl.deleteTextures(2, &[_]GLuint{ emu_tex, out_tex });

        const fbo_id = try opengl_impl.createFrameBuffer(out_tex);
        defer gl.deleteFramebuffers(1, &fbo_id);

        // TODO: Support dynamically switching shaders?
        const prog_id = try opengl_impl.compileShaders();
        defer gl.deleteProgram(prog_id);

        var win_dim: Dimensions = default_dim;

        emu_loop: while (true) {
            // Outside of `SDL.SDL_QUIT` below, the DearImgui UI might signal that the program
            // should exit, in which case we should also handle this
            if (self.state.should_quit) break :emu_loop;

            var event: SDL.SDL_Event = undefined;
            while (SDL.SDL_PollEvent(&event) != 0) {
                _ = zgui.backend.processEvent(&event);

                switch (event.type) {
                    SDL.SDL_QUIT => break :emu_loop,
                    SDL.SDL_KEYDOWN => {
                        // TODO: Make use of compare_and_xor?
                        const key_code = event.key.keysym.sym;
                        var keyinput = cpu.bus.io.keyinput.load(.Monotonic);

                        switch (key_code) {
                            SDL.SDLK_UP => keyinput.up.unset(),
                            SDL.SDLK_DOWN => keyinput.down.unset(),
                            SDL.SDLK_LEFT => keyinput.left.unset(),
                            SDL.SDLK_RIGHT => keyinput.right.unset(),
                            SDL.SDLK_x => keyinput.a.unset(),
                            SDL.SDLK_z => keyinput.b.unset(),
                            SDL.SDLK_a => keyinput.shoulder_l.unset(),
                            SDL.SDLK_s => keyinput.shoulder_r.unset(),
                            SDL.SDLK_RETURN => keyinput.start.unset(),
                            SDL.SDLK_RSHIFT => keyinput.select.unset(),
                            else => {},
                        }

                        cpu.bus.io.keyinput.store(keyinput.raw, .Monotonic);
                    },
                    SDL.SDL_KEYUP => {
                        // TODO: Make use of compare_and_xor?
                        const key_code = event.key.keysym.sym;
                        var keyinput = cpu.bus.io.keyinput.load(.Monotonic);

                        switch (key_code) {
                            SDL.SDLK_UP => keyinput.up.set(),
                            SDL.SDLK_DOWN => keyinput.down.set(),
                            SDL.SDLK_LEFT => keyinput.left.set(),
                            SDL.SDLK_RIGHT => keyinput.right.set(),
                            SDL.SDLK_x => keyinput.a.set(),
                            SDL.SDLK_z => keyinput.b.set(),
                            SDL.SDLK_a => keyinput.shoulder_l.set(),
                            SDL.SDLK_s => keyinput.shoulder_r.set(),
                            SDL.SDLK_RETURN => keyinput.start.set(),
                            SDL.SDLK_RSHIFT => keyinput.select.set(),
                            else => {},
                        }

                        cpu.bus.io.keyinput.store(keyinput.raw, .Monotonic);
                    },
                    SDL.SDL_WINDOWEVENT => {
                        if (event.window.event == SDL.SDL_WINDOWEVENT_RESIZED) {
                            log.debug("window resized to: {}x{}", .{ event.window.data1, event.window.data2 });

                            win_dim.width = @intCast(u32, event.window.data1);
                            win_dim.height = @intCast(u32, event.window.data2);
                        }
                    },
                    else => {},
                }
            }

            var zgui_redraw: bool = false;

            switch (self.state.emulation) {
                .Transition => |inner| switch (inner) {
                    .Active => {
                        _ = channel.gui.pop();

                        channel.emu.push(.Resume);
                        self.state.emulation = .Active;
                    },
                    .Inactive => {
                        // Assert that double pausing is impossible
                        if (channel.gui.peek()) |value|
                            std.debug.assert(value != .Paused);

                        channel.emu.push(.Pause);
                        self.state.emulation = .Inactive;
                    },
                },
                .Active => skip_draw: {
                    const is_std = mode == .Standard;

                    if (is_std) channel.emu.push(.Pause);
                    defer if (is_std) channel.emu.push(.Resume);

                    switch (mode) {
                        .Standard => blk: {
                            const limit = 15; // TODO: What should this be?

                            // TODO: learn more about std.atomic.spinLoopHint();
                            for (0..limit) |_| {
                                const message = channel.gui.pop() orelse continue;

                                switch (message) {
                                    .Paused => break :blk,
                                    .Quit => unreachable,
                                }
                            }

                            log.info("timed out waiting for emu thread to pause (limit: {})", .{limit});
                            break :skip_draw;
                        },
                        .Debug => blk: {
                            switch (channel.gui.pop() orelse break :blk) {
                                .Paused => unreachable, // only in standard mode
                                .Quit => break :emu_loop, // FIXME: gdb side of emu is seriously out-of-date...
                            }
                        },
                    }

                    // Add FPS count to the histogram
                    if (tracker) |t| self.state.fps_hist.push(t.value()) catch {};

                    // Draw GBA Screen to Texture
                    {
                        gl.bindFramebuffer(gl.FRAMEBUFFER, fbo_id);
                        defer gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

                        const buf = cpu.bus.ppu.framebuf.get(.Renderer);
                        gl.viewport(0, 0, gba_width, gba_height);
                        opengl_impl.drawScreenTexture(emu_tex, prog_id, objects, buf);
                    }

                    zgui_redraw = imgui.draw(&self.state, win_dim, out_tex, cpu);
                },
                .Inactive => zgui_redraw = imgui.draw(&self.state, win_dim, out_tex, cpu),
            }

            if (zgui_redraw) {
                // Background Colour
                const size = zgui.io.getDisplaySize();
                gl.viewport(0, 0, @floatToInt(GLsizei, size[0]), @floatToInt(GLsizei, size[1]));
                gl.clearColor(0, 0, 0, 1.0);
                gl.clear(gl.COLOR_BUFFER_BIT);

                zgui.backend.draw();
            }

            SDL.SDL_GL_SwapWindow(self.window);
        }

        channel.emu.push(.Quit);
    }

    fn glGetProcAddress(ctx: SDL.SDL_GLContext, proc: [:0]const u8) ?*anyopaque {
        _ = ctx;
        return SDL.SDL_GL_GetProcAddress(proc.ptr);
    }
};

const Audio = struct {
    const Self = @This();
    const log = std.log.scoped(.PlatformAudio);

    device: SDL.SDL_AudioDeviceID,

    fn init(apu: *Apu) Self {
        var have: SDL.SDL_AudioSpec = undefined;
        var want: SDL.SDL_AudioSpec = std.mem.zeroes(SDL.SDL_AudioSpec);
        want.freq = sample_rate;
        want.format = sample_format;
        want.channels = 2;
        want.samples = 0x100;
        want.callback = Self.callback;
        want.userdata = apu;

        std.debug.assert(sample_format == SDL.AUDIO_U16);
        log.info("Host Sample Rate: {}Hz, Host Format: SDL.AUDIO_U16", .{sample_rate});

        const device = SDL.SDL_OpenAudioDevice(null, 0, &want, &have, 0);
        if (device == 0) panic();

        if (!config.config().host.mute) {
            SDL.SDL_PauseAudioDevice(device, 0); // Unpause Audio
            log.info("Unpaused Device", .{});
        }

        return .{ .device = device };
    }

    fn deinit(self: *Self) void {
        SDL.SDL_CloseAudioDevice(self.device);
        self.* = undefined;
    }

    export fn callback(userdata: ?*anyopaque, stream: [*c]u8, len: c_int) void {
        const T = *Apu;
        const apu = @ptrCast(T, @alignCast(@alignOf(T), userdata));

        _ = SDL.SDL_AudioStreamGet(apu.stream, stream, len);
    }
};

fn panic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}

const opengl_impl = struct {
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

    const Objects = struct { vao: GLuint, vbo: GLuint, ebo: GLuint };

    fn drawScreenTexture(tex_id: GLuint, prog_id: GLuint, ids: Objects, buf: []const u8) void {
        gl.bindTexture(gl.TEXTURE_2D, tex_id);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);

        gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, gba_width, gba_height, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, buf.ptr);

        // Bind VAO, EBO. VBO not bound
        gl.bindVertexArray(ids.vao); // VAO
        defer gl.bindVertexArray(0);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ids.ebo); // EBO
        defer gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        // Use compiled frag + vertex shader
        gl.useProgram(prog_id);
        defer gl.useProgram(0);

        gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
    }

    fn compileShaders() !GLuint {
        const vert_shader = @embedFile("shader/pixelbuf.vert");
        const frag_shader = @embedFile("shader/pixelbuf.frag");

        const vs = gl.createShader(gl.VERTEX_SHADER);
        defer gl.deleteShader(vs);

        gl.shaderSource(vs, 1, &[_][*c]const u8{vert_shader}, 0);
        gl.compileShader(vs);

        if (!shader.didCompile(vs)) return error.VertexCompileError;

        const fs = gl.createShader(gl.FRAGMENT_SHADER);
        defer gl.deleteShader(fs);

        gl.shaderSource(fs, 1, &[_][*c]const u8{frag_shader}, 0);
        gl.compileShader(fs);

        if (!shader.didCompile(fs)) return error.FragmentCompileError;

        const program = gl.createProgram();
        gl.attachShader(program, vs);
        gl.attachShader(program, fs);
        gl.linkProgram(program);

        return program;
    }

    // Returns the VAO ID since it's used in run()
    fn createObjects() Objects {
        var vao_id: GLuint = undefined;
        var vbo_id: GLuint = undefined;
        var ebo_id: GLuint = undefined;

        gl.genVertexArrays(1, &vao_id);
        gl.genBuffers(1, &vbo_id);
        gl.genBuffers(1, &ebo_id);

        gl.bindVertexArray(vao_id);
        defer gl.bindVertexArray(0);

        gl.bindBuffer(gl.ARRAY_BUFFER, vbo_id);
        defer gl.bindBuffer(gl.ARRAY_BUFFER, 0);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo_id);
        defer gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);

        // Position
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), null); // lmao
        gl.enableVertexAttribArray(0);
        // Colour
        gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, (3 * @sizeOf(f32))));
        gl.enableVertexAttribArray(1);
        // Texture Coord
        gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @intToPtr(?*anyopaque, (6 * @sizeOf(f32))));
        gl.enableVertexAttribArray(2);

        return .{ .vao = vao_id, .vbo = vbo_id, .ebo = ebo_id };
    }

    fn createScreenTexture(buf: []const u8) GLuint {
        var tex_id: GLuint = undefined;
        gl.genTextures(1, &tex_id);

        gl.bindTexture(gl.TEXTURE_2D, tex_id);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gba_width, gba_height, 0, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, buf.ptr);

        return tex_id;
    }

    fn createOutputTexture() GLuint {
        var tex_id: GLuint = undefined;
        gl.genTextures(1, &tex_id);

        gl.bindTexture(gl.TEXTURE_2D, tex_id);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gba_width, gba_height, 0, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, null);

        return tex_id;
    }

    fn createFrameBuffer(tex_id: GLuint) !GLuint {
        var fbo_id: GLuint = undefined;
        gl.genFramebuffers(1, &fbo_id);

        gl.bindFramebuffer(gl.FRAMEBUFFER, fbo_id);
        defer gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

        gl.framebufferTexture(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, tex_id, 0);

        const draw_buffers: [1]GLuint = .{gl.COLOR_ATTACHMENT0};
        gl.drawBuffers(1, &draw_buffers);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE)
            return error.FrameBufferObejctInitFailed;

        return fbo_id;
    }

    const shader = struct {
        const Kind = enum { vertex, fragment };
        const log = std.log.scoped(.Shader);

        fn didCompile(id: gl.GLuint) bool {
            var success: gl.GLint = undefined;
            gl.getShaderiv(id, gl.COMPILE_STATUS, &success);

            if (success == 0) err(id);

            return success == 1;
        }

        fn err(id: gl.GLuint) void {
            const buf_len = 512;
            var error_msg: [buf_len]u8 = undefined;

            gl.getShaderInfoLog(id, buf_len, 0, &error_msg);
            log.err("{s}", .{std.mem.sliceTo(&error_msg, 0)});
        }
    };
};
