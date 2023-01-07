const std = @import("std");
const SDL = @import("sdl2");
const gl = @import("gl");
const zgui = @import("zgui");

const emu = @import("core/emu.zig");
const config = @import("config.zig");

const Apu = @import("core/apu.zig").Apu;
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FpsTracker = @import("util.zig").FpsTracker;
const RingBuffer = @import("util.zig").RingBuffer;

const gba_width = @import("core/ppu.zig").width;
const gba_height = @import("core/ppu.zig").height;

const GLuint = gl.GLuint;
const GLsizei = gl.GLsizei;
const SDL_GLContext = *anyopaque;
const Allocator = std.mem.Allocator;

const width = 1280;
const height = 720;

pub const sample_rate = 1 << 15;
pub const sample_format = SDL.AUDIO_U16;

const default_title = "ZBA";

pub const Gui = struct {
    const Self = @This();
    const log = std.log.scoped(.Gui);

    const State = struct {
        fps_hist: RingBuffer(u32),
        allocator: Allocator,

        pub fn init(allocator: Allocator) !@This() {
            const history = try allocator.alloc(u32, 0x400);

            return .{
                .fps_hist = RingBuffer(u32).init(history),
                .allocator = allocator,
            };
        }

        fn deinit(self: *@This()) void {
            self.fps_hist.deinit(self.allocator);
            self.* = undefined;
        }
    };

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

    state: State,

    program_id: gl.GLuint,

    pub fn init(allocator: Allocator, title: *const [12]u8, apu: *Apu) !Self {
        if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_PROFILE_MASK, SDL.SDL_GL_CONTEXT_PROFILE_CORE) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, 3) < 0) panic();
        if (SDL.SDL_GL_SetAttribute(SDL.SDL_GL_CONTEXT_MAJOR_VERSION, 3) < 0) panic();

        const window = SDL.SDL_CreateWindow(
            default_title,
            SDL.SDL_WINDOWPOS_CENTERED,
            SDL.SDL_WINDOWPOS_CENTERED,
            width,
            height,
            SDL.SDL_WINDOW_OPENGL | SDL.SDL_WINDOW_SHOWN,
        ) orelse panic();

        const ctx = SDL.SDL_GL_CreateContext(window) orelse panic();
        if (SDL.SDL_GL_MakeCurrent(window, ctx) < 0) panic();

        gl.load(ctx, Self.glGetProcAddress) catch {};
        if (SDL.SDL_GL_SetSwapInterval(@boolToInt(config.config().host.vsync)) < 0) panic();

        zgui.init(allocator);
        zgui.plot.init();
        zgui.backend.init(window, ctx, "#version 330 core");

        zgui.io.setIniFilename(null);

        return Self{
            .window = window,
            .title = std.mem.sliceTo(title, 0),
            .ctx = ctx,
            .program_id = try compileShaders(),
            .audio = Audio.init(apu),

            .state = try State.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.audio.deinit();
        self.state.deinit();

        zgui.backend.deinit();
        zgui.plot.deinit();
        zgui.deinit();

        gl.deleteProgram(self.program_id);
        SDL.SDL_GL_DeleteContext(self.ctx);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
        self.* = undefined;
    }

    fn drawGbaTexture(self: *const Self, obj_ids: struct { GLuint, GLuint, GLuint }, tex_id: GLuint, buf: []const u8) void {
        gl.bindTexture(gl.TEXTURE_2D, tex_id);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);

        gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, gba_width, gba_height, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, buf.ptr);

        // Bind VAO, EBO. VBO not bound
        gl.bindVertexArray(obj_ids[0]); // VAO
        defer gl.bindVertexArray(0);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, obj_ids[2]); // EBO
        defer gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        // Use compiled frag + vertex shader
        gl.useProgram(self.program_id);
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
    fn genBufferObjects() struct { GLuint, GLuint, GLuint } {
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

    fn genGbaTexture(buf: []const u8) GLuint {
        var tex_id: GLuint = undefined;
        gl.genTextures(1, &tex_id);

        gl.bindTexture(gl.TEXTURE_2D, tex_id);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gba_width, gba_height, 0, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, buf.ptr);

        return tex_id;
    }

    fn genOutTexture() GLuint {
        var tex_id: GLuint = undefined;
        gl.genTextures(1, &tex_id);

        gl.bindTexture(gl.TEXTURE_2D, tex_id);
        defer gl.bindTexture(gl.TEXTURE_2D, 0);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gba_width, gba_height, 0, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, null);

        return tex_id;
    }

    fn genFrameBufObject(tex_id: c_uint) !GLuint {
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

    fn draw(self: *Self, tex_id: GLuint, cpu: *const Arm7tdmi) void {
        _ = cpu;
        const win_scale = config.config().host.win_scale;

        {
            _ = zgui.begin("Game Boy Advance Screen", .{ .flags = .{ .no_resize = true, .always_auto_resize = true } });
            defer zgui.end();

            const img_args = .{
                .w = @intToFloat(f32, gba_width * win_scale),
                .h = @intToFloat(f32, gba_height * win_scale),
                .uv0 = .{ 0.0, 1.0 },
                .uv1 = .{ 1.0, 0.0 },
            };

            zgui.image(@intToPtr(*anyopaque, tex_id), img_args);
        }

        {
            _ = zgui.begin("Emulator Performance", .{});

            const tmp = blk: {
                var buf: [0x400]u32 = undefined;
                const len = self.state.fps_hist.copy(&buf);

                break :blk .{ buf, len };
            };
            const values = tmp[0];
            const len = tmp[1];

            if (len == values.len) _ = self.state.fps_hist.pop();

            const sorted = blk: {
                var buf: @TypeOf(values) = undefined;

                std.mem.copy(u32, buf[0..len], values[0..len]);
                std.sort.sort(u32, buf[0..len], {}, std.sort.asc(u32));

                break :blk buf;
            };

            const y_max = 2 * if (len != 0) @intToFloat(f64, sorted[len - 1]) else emu.frame_rate;
            const x_max = @intToFloat(f64, values.len);

            const y_args = .{ .flags = .{ .no_grid_lines = true } };
            const x_args = .{ .flags = .{ .no_grid_lines = true, .no_tick_labels = true, .no_tick_marks = true } };

            if (zgui.plot.beginPlot("Emulation FPS", .{ .w = 0.0, .flags = .{ .no_title = true, .no_frame = true } })) {
                zgui.plot.setupLegend(.{ .north = true, .east = true }, .{});
                zgui.plot.setupAxis(.x1, x_args);
                zgui.plot.setupAxis(.y1, y_args);
                zgui.plot.setupAxisLimits(.y1, .{ .min = 0.0, .max = y_max, .cond = .always });
                zgui.plot.setupAxisLimits(.x1, .{ .min = 0.0, .max = x_max, .cond = .always });
                zgui.plot.setupFinish();

                zgui.plot.plotLineValues("FPS", u32, .{ .v = values[0..len] });
                zgui.plot.endPlot();
            }

            const stats: struct { u32, u32, u32 } = blk: {
                if (len == 0) break :blk .{ 0, 0, 0 };

                const average = average: {
                    var sum: u32 = 0;
                    for (sorted[0..len]) |value| sum += value;

                    break :average @intCast(u32, sum / len);
                };
                const median = sorted[len / 2];
                const low = sorted[len / 100]; // 1% Low

                break :blk .{ average, median, low };
            };

            zgui.text("Average: {:0>3} fps", .{stats[0]});
            zgui.text(" Median: {:0>3} fps", .{stats[1]});
            zgui.text(" 1% Low: {:0>3} fps", .{stats[2]});

            defer zgui.end();
        }

        {
            zgui.showDemoWindow(null);
        }
    }

    const RunOptions = struct {
        quit: *std.atomic.Atomic(bool),
        tracker: ?*FpsTracker = null,
        cpu: *Arm7tdmi,
        scheduler: *Scheduler,
    };

    pub fn run(self: *Self, opt: RunOptions) !void {
        const cpu = opt.cpu;
        const tracker = opt.tracker;
        const quit = opt.quit;

        const obj_ids = Self.genBufferObjects();
        defer gl.deleteBuffers(3, @as(*const [3]c_uint, &obj_ids));

        const emu_tex = Self.genGbaTexture(cpu.bus.ppu.framebuf.get(.Renderer));
        const out_tex = Self.genOutTexture();
        defer gl.deleteTextures(2, &[_]c_uint{ emu_tex, out_tex });

        const fbo_id = try Self.genFrameBufObject(out_tex);
        defer gl.deleteFramebuffers(1, &fbo_id);

        var quit = std.atomic.Atomic(bool).init(false);
        var tracker = FpsTracker.init();

        var title_buf: [0x100]u8 = undefined;

        emu_loop: while (true) {
            var event: SDL.SDL_Event = undefined;

            // This might be true if the emu is running via a gdbstub server
            // and the gdb stub exits first
            if (quit.load(.Monotonic)) break :emu_loop;

            while (SDL.SDL_PollEvent(&event) != 0) {
                _ = zgui.backend.processEvent(&event);

                switch (event.type) {
                    SDL.SDL_QUIT => break :emu_loop,
                    SDL.SDL_KEYDOWN => {
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
                            SDL.SDLK_i => {
                                comptime std.debug.assert(sample_format == SDL.AUDIO_U16);
                                log.err("Sample Count: {}", .{@intCast(u32, SDL.SDL_AudioStreamAvailable(cpu.bus.apu.stream)) / (2 * @sizeOf(u16))});
                            },
                            // SDL.SDLK_j => log.err("Scheduler Capacity: {} | Scheduler Event Count: {}", .{ scheduler.queue.capacity(), scheduler.queue.count() }),
                            SDL.SDLK_k => {},
                            else => {},
                        }

                        cpu.bus.io.keyinput.store(keyinput.raw, .Monotonic);
                    },
                    else => {},
                }
            }

            {
                gl.bindFramebuffer(gl.FRAMEBUFFER, fbo_id);
                defer gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

                const buf = cpu.bus.ppu.framebuf.get(.Renderer);
                gl.viewport(0, 0, gba_width, gba_height);
                self.drawGbaTexture(obj_ids, emu_tex, buf);
            }

            // Background
            const size = zgui.io.getDisplaySize();
            gl.viewport(0, 0, @floatToInt(c_int, size[0]), @floatToInt(c_int, size[1]));
            gl.clearColor(0, 0, 0, 1.0);
            gl.clear(gl.COLOR_BUFFER_BIT);

            zgui.backend.newFrame(width, height);
            self.draw(out_tex, cpu);
            zgui.backend.draw();

            SDL.SDL_GL_SwapWindow(self.window);

            if (tracker) |t| {
                const emu_fps = t.value();
                self.state.fps_hist.push(emu_fps) catch {};

                const dyn_title = std.fmt.bufPrintZ(&title_buf, "ZBA | {s} [Emu: {}fps] ", .{ self.title, emu_fps }) catch unreachable;
                SDL.SDL_SetWindowTitle(self.window, dyn_title.ptr);
            }
        }

        quit.store(true, .Monotonic); // Terminate Emulator Thread
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

fn panic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
