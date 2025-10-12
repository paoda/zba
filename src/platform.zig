const std = @import("std");
const gl = @import("gl");
const zgui = @import("zgui");
const c = @import("lib.zig").c;

const emu = @import("core/emu.zig");
const config = @import("config.zig");
const imgui = @import("imgui.zig");

const Apu = @import("core/apu.zig").Apu;
const Arm7tdmi = @import("arm32").Arm7tdmi;
const Bus = @import("core/Bus.zig");
const Scheduler = @import("core/scheduler.zig").Scheduler;
const FpsTracker = @import("util.zig").FpsTracker;
const Synchro = @import("core/emu.zig").Synchro;
const KeyInput = @import("core/bus/io.zig").KeyInput;

const gba_width = @import("core/ppu.zig").width;
const gba_height = @import("core/ppu.zig").height;

const GLsizei = gl.sizei;
const SDL_GLContext = *c.SDL_GLContextState;
const Allocator = std.mem.Allocator;

pub const Dimensions = struct { width: u32, height: u32 };
const default_dim: Dimensions = .{ .width = 1280, .height = 720 };

pub const sample_rate = 1 << 15;
// pub const sample_format = SDL.AUDIO_U16;

const window_title = "ZBA";

const errify = @import("lib.zig").errify;

var gl_procs: gl.ProcTable = undefined;

pub const Gui = struct {
    const Self = @This();
    const log = std.log.scoped(.Gui);

    window: *c.SDL_Window,
    ctx: SDL_GLContext,
    audio: Audio,

    state: imgui.State,
    allocator: Allocator,

    pub fn init(allocator: Allocator, apu: *Apu, title_opt: ?*const [12]u8) !Self {
        c.SDL_SetMainReady();

        try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_EVENTS));

        try errify(c.SDL_SetAppMetadata(window_title, "0.1.0", "moe.paoda.zba"));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, gl.info.version_major));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, gl.info.version_minor));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG));

        const window: *c.SDL_Window = try errify(c.SDL_CreateWindow(window_title, default_dim.width, default_dim.height, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE));
        errdefer c.SDL_DestroyWindow(window);

        const gl_ctx = try errify(c.SDL_GL_CreateContext(window));
        errdefer errify(c.SDL_GL_DestroyContext(gl_ctx)) catch {};

        try errify(c.SDL_GL_MakeCurrent(window, gl_ctx));
        errdefer errify(c.SDL_GL_MakeCurrent(window, null)) catch {};

        if (!gl_procs.init(c.SDL_GL_GetProcAddress)) return error.gl_init_failed;

        gl.makeProcTableCurrent(&gl_procs);
        errdefer gl.makeProcTableCurrent(null);

        try errify(c.SDL_GL_SetSwapInterval(@intFromBool(config.config().host.vsync)));

        zgui.init(allocator);
        zgui.plot.init();
        zgui.backend.init(window, gl_ctx);

        // zgui.io.setIniFilename(null);

        return Self{
            .window = window,
            .ctx = gl_ctx,
            .audio = try Audio.init(apu),

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

        errify(c.SDL_GL_DestroyContext(self.ctx)) catch {};
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();

        self.* = undefined;
    }

    const RunOptions = struct {
        sync: *Synchro,
        tracker: ?*FpsTracker = null,
        cpu: *Arm7tdmi,
        scheduler: *Scheduler,
    };

    pub fn run(self: *Self, opt: RunOptions) !void {
        const cpu = opt.cpu;
        const tracker = opt.tracker;
        const sync = opt.sync;

        const bus_ptr: *Bus = @ptrCast(@alignCast(cpu.bus.ptr));

        const vao_id = opengl_impl.vao();
        defer gl.DeleteVertexArrays(1, vao_id[0..]);

        const emu_tex = opengl_impl.screenTex(bus_ptr.ppu.framebuf.get(.Renderer));
        defer gl.DeleteTextures(1, emu_tex[0..]);

        const out_tex = opengl_impl.outTex();
        defer gl.DeleteTextures(1, out_tex[0..]);

        const fbo_id = try opengl_impl.frameBuffer(out_tex[0]);
        defer gl.DeleteFramebuffers(1, fbo_id[0..]);

        const prog_id = try opengl_impl.program(); // Dynamic Shaders?
        defer gl.DeleteProgram(prog_id);

        var win_dim: Dimensions = default_dim;

        emu_loop: while (true) {
            // Outside of `SDL.SDL_QUIT` below, the DearImgui UI might signal that the program
            // should exit, in which case we should also handle this
            if (self.state.should_quit or sync.should_quit.load(.monotonic)) break :emu_loop;

            var event: c.SDL_Event = undefined;

            while (c.SDL_PollEvent(&event)) {
                _ = zgui.backend.processEvent(&event);

                switch (event.type) {
                    c.SDL_EVENT_QUIT => break :emu_loop,
                    c.SDL_EVENT_KEY_DOWN => {
                        // TODO: Make use of compare_and_xor?
                        var keyinput: KeyInput = .{ .raw = 0x0000 };

                        switch (event.key.scancode) {
                            c.SDL_SCANCODE_UP => keyinput.up.write(true),
                            c.SDL_SCANCODE_DOWN => keyinput.down.write(true),
                            c.SDL_SCANCODE_LEFT => keyinput.left.write(true),
                            c.SDL_SCANCODE_RIGHT => keyinput.right.write(true),
                            c.SDL_SCANCODE_X => keyinput.a.write(true),
                            c.SDL_SCANCODE_Z => keyinput.b.write(true),
                            c.SDL_SCANCODE_A => keyinput.shoulder_l.write(true),
                            c.SDL_SCANCODE_S => keyinput.shoulder_r.write(true),
                            c.SDL_SCANCODE_RETURN => keyinput.start.write(true),
                            c.SDL_SCANCODE_RSHIFT => keyinput.select.write(true),
                            else => {},
                        }

                        bus_ptr.io.keyinput.fetchAnd(~keyinput.raw, .monotonic);
                    },
                    c.SDL_EVENT_KEY_UP => {
                        // FIXME(paoda): merge with above?
                        // TODO: Make use of compare_and_xor?
                        var keyinput: KeyInput = .{ .raw = 0x0000 };

                        switch (event.key.scancode) {
                            c.SDL_SCANCODE_UP => keyinput.up.write(true),
                            c.SDL_SCANCODE_DOWN => keyinput.down.write(true),
                            c.SDL_SCANCODE_LEFT => keyinput.left.write(true),
                            c.SDL_SCANCODE_RIGHT => keyinput.right.write(true),
                            c.SDL_SCANCODE_X => keyinput.a.write(true),
                            c.SDL_SCANCODE_Z => keyinput.b.write(true),
                            c.SDL_SCANCODE_A => keyinput.shoulder_l.write(true),
                            c.SDL_SCANCODE_S => keyinput.shoulder_r.write(true),
                            c.SDL_SCANCODE_RETURN => keyinput.start.write(true),
                            c.SDL_SCANCODE_RSHIFT => keyinput.select.write(true),
                            else => {},
                        }

                        bus_ptr.io.keyinput.fetchOr(keyinput.raw, .monotonic);
                    },
                    c.SDL_EVENT_WINDOW_RESIZED => {
                        log.debug("window resized to: {}x{}", .{ event.window.data1, event.window.data2 });

                        win_dim.width = @intCast(event.window.data1);
                        win_dim.height = @intCast(event.window.data2);
                    },
                    else => {},
                }
            }

            var zgui_redraw: bool = false;

            switch (self.state.emulation) {
                .Transition => |inner| switch (inner) {
                    .Active => {
                        sync.paused.store(false, .monotonic);
                        if (!config.config().host.mute) try errify(c.SDL_PauseAudioDevice(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK));

                        self.state.emulation = .Active;
                    },
                    .Inactive => {
                        // Assert that double pausing is impossible
                        try errify(c.SDL_ResumeAudioDevice(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK));
                        sync.paused.store(true, .monotonic);

                        self.state.emulation = .Inactive;
                    },
                },
                .Active => {
                    // Add FPS count to the histogram
                    if (tracker) |t| self.state.fps_hist.push(t.value()) catch {};

                    // Draw GBA Screen to Texture
                    {
                        gl.BindFramebuffer(gl.FRAMEBUFFER, fbo_id[0]);
                        defer gl.BindFramebuffer(gl.FRAMEBUFFER, 0);

                        gl.Viewport(0, 0, gba_width, gba_height);
                        opengl_impl.drawScreen(emu_tex[0], prog_id, vao_id[0], bus_ptr.ppu.framebuf.get(.Renderer));
                    }

                    // FIXME: We only really care about locking the audio device (and therefore writing silence)
                    // since if nfd-zig is used the emu may be paused for way too long. Perhaps we should try and limit
                    // spurious calls to SDL_LockAudioDevice?

                    try errify(c.SDL_LockAudioStream(self.audio.stream));
                    defer errify(c.SDL_UnlockAudioStream(self.audio.stream)) catch @panic("TODO: FIXME");

                    zgui_redraw = imgui.draw(&self.state, sync, win_dim, cpu, out_tex[0]);
                },
                .Inactive => zgui_redraw = imgui.draw(&self.state, sync, win_dim, cpu, out_tex[0]),
            }

            if (zgui_redraw) {
                // Background Colour
                const size = zgui.io.getDisplaySize();
                gl.Viewport(0, 0, @intFromFloat(size[0]), @intFromFloat(size[1]));
                gl.ClearColor(0, 0, 0, 1.0);
                gl.Clear(gl.COLOR_BUFFER_BIT);

                zgui.backend.draw();
            }

            try errify(c.SDL_GL_SwapWindow(self.window));
        }

        sync.should_quit.store(true, .monotonic);
    }
};

const Audio = struct {
    const Self = @This();
    const log = std.log.scoped(.PlatformAudio);

    stream: *c.SDL_AudioStream,

    fn init(apu: *Apu) !Self {
        var desired: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec);
        desired.freq = sample_rate;
        desired.format = c.SDL_AUDIO_S16LE;
        desired.channels = 2;

        log.info("Host Sample Rate: {}Hz, Host Format: SDL_AUDIO_S16LE", .{sample_rate});

        const stream = try errify(c.SDL_OpenAudioDeviceStream(c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &desired, null, null));
        errdefer c.SDL_DestroyAudioStream(stream);

        apu.stream = stream;
        return .{ .stream = stream };
    }

    fn deinit(self: *Self) void {
        c.SDL_DestroyAudioStream(self.stream);
        self.* = undefined;
    }
};

const opengl_impl = struct {
    fn drawScreen(tex_id: gl.uint, prog_id: gl.uint, vao_id: gl.uint, buf: []const u8) void {
        gl.BindTexture(gl.TEXTURE_2D, tex_id);
        defer gl.BindTexture(gl.TEXTURE_2D, 0);

        gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, gba_width, gba_height, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, buf.ptr);

        // Bind VAO
        gl.BindVertexArray(vao_id);
        defer gl.BindVertexArray(0);

        // Use compiled frag + vertex shader
        gl.UseProgram(prog_id);
        defer gl.UseProgram(0);

        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 3);
    }

    fn program() !gl.uint {
        const vert_shader: [1][*]const u8 = .{@embedFile("shader/pixelbuf.vert")};
        const frag_shader: [1][*]const u8 = .{@embedFile("shader/pixelbuf.frag")};

        const vs = gl.CreateShader(gl.VERTEX_SHADER);
        defer gl.DeleteShader(vs);

        gl.ShaderSource(vs, 1, vert_shader[0..], null);
        gl.CompileShader(vs);

        if (!shader.didCompile(vs)) return error.VertexCompileError;

        const fs = gl.CreateShader(gl.FRAGMENT_SHADER);
        defer gl.DeleteShader(fs);

        gl.ShaderSource(fs, 1, frag_shader[0..], null);
        gl.CompileShader(fs);

        if (!shader.didCompile(fs)) return error.FragmentCompileError;

        const prog = gl.CreateProgram();
        gl.AttachShader(prog, vs);
        gl.AttachShader(prog, fs);
        gl.LinkProgram(prog);

        return prog;
    }

    fn vao() [1]gl.uint {
        var vao_id: [1]gl.uint = undefined;
        gl.GenVertexArrays(1, vao_id[0..]);

        return vao_id;
    }

    fn screenTex(buf: []const u8) [1]gl.uint {
        var tex_id: [1]gl.uint = undefined;
        gl.GenTextures(1, tex_id[0..]);

        gl.BindTexture(gl.TEXTURE_2D, tex_id[0]);
        defer gl.BindTexture(gl.TEXTURE_2D, 0);

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gba_width, gba_height, 0, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, buf.ptr);

        return tex_id;
    }

    fn outTex() [1]gl.uint {
        var tex_id: [1]gl.uint = undefined;
        gl.GenTextures(1, tex_id[0..]);

        gl.BindTexture(gl.TEXTURE_2D, tex_id[0]);
        defer gl.BindTexture(gl.TEXTURE_2D, 0);

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gba_width, gba_height, 0, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, null);

        return tex_id;
    }

    fn frameBuffer(tex_id: gl.uint) ![1]gl.uint {
        var fbo_id: [1]gl.uint = undefined;
        gl.GenFramebuffers(1, fbo_id[0..]);

        gl.BindFramebuffer(gl.FRAMEBUFFER, fbo_id[0]);
        defer gl.BindFramebuffer(gl.FRAMEBUFFER, 0);

        gl.FramebufferTexture(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, tex_id, 0);
        gl.DrawBuffers(1, &.{gl.COLOR_ATTACHMENT0});

        if (gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE)
            return error.FrameBufferObejctInitFailed;

        return fbo_id;
    }

    const shader = struct {
        const log = std.log.scoped(.shader);

        fn didCompile(id: gl.uint) bool {
            var success: [1]gl.int = undefined;
            gl.GetShaderiv(id, gl.COMPILE_STATUS, success[0..]);

            if (success[0] == 0) err(id);

            return success[0] == 1;
        }

        fn err(id: gl.uint) void {
            const buf_len = 512;
            var error_msg: [buf_len]u8 = undefined;

            gl.GetShaderInfoLog(id, buf_len, null, &error_msg);
            log.err("{s}", .{std.mem.sliceTo(&error_msg, 0)});
        }
    };
};
