//! Namespace for dealing with ZBA's immediate-mode GUI
//! Currently, ZBA uses zgui from https://github.com/michal-z/zig-gamedev
//! which provides Zig bindings for https://github.com/ocornut/imgui under the hood

const std = @import("std");
const zgui = @import("zgui");
const gl = @import("gl");
const nfd = @import("nfd");
const config = @import("config.zig");
const emu = @import("core/emu.zig");

const Gui = @import("platform.zig").Gui;
const Arm7tdmi = @import("arm32").Arm7tdmi;
const Scheduler = @import("core/scheduler.zig").Scheduler;
const Bus = @import("core/Bus.zig");
const Synchro = @import("core/emu.zig").Synchro;

const RingBuffer = @import("zba-util").RingBuffer;
const Dimensions = @import("platform.zig").Dimensions;

const Allocator = std.mem.Allocator;
const GLuint = gl.GLuint;

const gba_width = @import("core/ppu.zig").width;
const gba_height = @import("core/ppu.zig").height;

const log = std.log.scoped(.Imgui);

// two seconds worth of fps values into the past
const histogram_len = 0x80;

/// Immediate-Mode GUI State
pub const State = struct {
    title: [12:0]u8,

    fps_hist: RingBuffer(u32),
    should_quit: bool = false,
    emulation: Emulation,

    win_stat: WindowStatus = .{},

    const WindowStatus = struct {
        show_deps: bool = false,
        show_regs: bool = false,
        show_schedule: bool = false,
        show_perf: bool = false,
        show_palette: bool = false,
    };

    const Emulation = union(enum) {
        Active,
        Inactive,
        Transition: enum { Active, Inactive },
    };

    /// if zba is initialized with a ROM already provided, this initializer should be called
    /// with `title_opt` being non-null
    pub fn init(allocator: Allocator, title_opt: ?*const [12]u8) !@This() {
        const history = try allocator.alloc(u32, histogram_len);

        return .{
            .title = handleTitle(title_opt),
            .emulation = if (title_opt == null) .Inactive else .{ .Transition = .Active },
            .fps_hist = RingBuffer(u32).init(history),
        };
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        allocator.free(self.fps_hist.buf);
        self.* = undefined;
    }
};

pub fn draw(state: *State, sync: *Synchro, dim: Dimensions, cpu: *const Arm7tdmi, tex_id: GLuint) bool {
    const scn_scale = config.config().host.win_scale;
    const bus_ptr: *Bus = @ptrCast(@alignCast(cpu.bus.ptr));

    zgui.backend.newFrame(@floatFromInt(dim.width), @floatFromInt(dim.height));

    state.title = handleTitle(&bus_ptr.pak.title);

    {
        _ = zgui.beginMainMenuBar();
        defer zgui.endMainMenuBar();

        if (zgui.beginMenu("File", true)) {
            defer zgui.endMenu();

            if (zgui.menuItem("Quit", .{}))
                state.should_quit = true;

            if (zgui.menuItem("Insert ROM", .{})) blk: {
                const file_path = tmp: {
                    const path_opt = nfd.openFileDialog("gba", null) catch |e| {
                        log.err("file dialog failed to open: {}", .{e});
                        break :blk;
                    };

                    break :tmp path_opt orelse {
                        log.warn("did not receive a file path", .{});
                        break :blk;
                    };
                };
                defer nfd.freePath(file_path);

                log.info("user chose: \"{s}\"", .{file_path});

                const message = tmp: {
                    var msg: Synchro.Message = .{ .rom_path = undefined };
                    @memcpy(msg.rom_path[0..file_path.len], file_path);
                    break :tmp msg;
                };

                sync.ch.push(message) catch |e| {
                    log.err("failed to send file path to emu thread: {}", .{e});
                    break :blk;
                };

                state.emulation = .{ .Transition = .Active };
            }

            if (zgui.menuItem("Load BIOS", .{})) blk: {
                const file_path = tmp: {
                    const path_opt = nfd.openFileDialog("bin", null) catch |e| {
                        log.err("file dialog failed to open: {}", .{e});
                        break :blk;
                    };

                    break :tmp path_opt orelse {
                        log.warn("did not receive a file path", .{});
                        break :blk;
                    };
                };
                defer nfd.freePath(file_path);

                log.info("user chose: \"{s}\"", .{file_path});

                const message = tmp: {
                    var msg: Synchro.Message = .{ .bios_path = undefined };
                    @memcpy(msg.bios_path[0..file_path.len], file_path);
                    break :tmp msg;
                };

                sync.ch.push(message) catch |e| {
                    log.err("failed to send file path to emu thread: {}", .{e});
                    break :blk;
                };
            }
        }

        if (zgui.beginMenu("Emulation", true)) {
            defer zgui.endMenu();

            if (zgui.menuItem("Registers", .{ .selected = state.win_stat.show_regs }))
                state.win_stat.show_regs = true;

            if (zgui.menuItem("Palette", .{ .selected = state.win_stat.show_palette }))
                state.win_stat.show_palette = true;

            if (zgui.menuItem("Schedule", .{ .selected = state.win_stat.show_schedule }))
                state.win_stat.show_schedule = true;

            if (zgui.menuItem("Paused", .{ .selected = state.emulation == .Inactive })) {
                state.emulation = switch (state.emulation) {
                    .Active => .{ .Transition = .Inactive },
                    .Inactive => .{ .Transition = .Active },
                    else => state.emulation,
                };
            }

            if (zgui.menuItem("Restart", .{}))
                sync.ch.push(.restart) catch |e| log.err("failed to send restart req to emu thread: {}", .{e});
        }

        if (zgui.beginMenu("Stats", true)) {
            defer zgui.endMenu();

            if (zgui.menuItem("Performance", .{ .selected = state.win_stat.show_perf }))
                state.win_stat.show_perf = true;
        }

        if (zgui.beginMenu("Help", true)) {
            defer zgui.endMenu();

            if (zgui.menuItem("Dependencies", .{ .selected = state.win_stat.show_deps }))
                state.win_stat.show_deps = true;
        }
    }

    {
        const w: f32 = @floatFromInt(gba_width * scn_scale);
        const h: f32 = @floatFromInt(gba_height * scn_scale);

        const window_title = std.mem.sliceTo(&state.title, 0);
        _ = zgui.begin(window_title, .{ .flags = .{ .no_resize = true, .always_auto_resize = true } });
        defer zgui.end();

        zgui.image(@ptrFromInt(tex_id), .{ .w = w, .h = h });
    }

    // TODO: Any other steps to respect the copyright of the libraries I use?
    if (state.win_stat.show_deps) {
        _ = zgui.begin("Dependencies", .{ .popen = &state.win_stat.show_deps });
        defer zgui.end();

        zgui.bulletText("known-folders by ziglibs", .{});
        zgui.bulletText("nfd-zig by Fabio Arnold", .{});
        {
            zgui.indent(.{});
            defer zgui.unindent(.{});

            zgui.bulletText("nativefiledialog by Michael Labbe", .{});
        }

        zgui.bulletText("SDL.zig by Felix Queißner", .{});
        {
            zgui.indent(.{});
            defer zgui.unindent(.{});

            zgui.bulletText("SDL by Sam Lantinga", .{});
        }

        zgui.bulletText("tomlz by Matthew Hall", .{});
        zgui.bulletText("zba-gdbstub by Rekai Musuka", .{});
        zgui.bulletText("zba-util by Rekai Musuka", .{});
        zgui.bulletText("zgui by Michal Ziulek", .{});
        {
            zgui.indent(.{});
            defer zgui.unindent(.{});

            zgui.bulletText("DearImGui by Omar Cornut", .{});
        }
        zgui.bulletText("zig-clap by Jimmi Holst Christensen", .{});
        zgui.bulletText("zig-datetime by Jairus Martin", .{});

        zgui.newLine();
        zgui.bulletText("bitfield.zig by Hannes Bredberg and FlorenceOS contributors", .{});
        zgui.bulletText("zig-opengl by Felix Queißner", .{});
        {
            zgui.indent(.{});
            defer zgui.unindent(.{});

            zgui.bulletText("OpenGL-Registry by The Khronos Group", .{});
        }
    }

    if (state.win_stat.show_regs) {
        _ = zgui.begin("Guest Registers", .{ .popen = &state.win_stat.show_regs });
        defer zgui.end();

        for (0..8) |i| {
            zgui.text("R{}: 0x{X:0>8}", .{ i, cpu.r[i] });

            zgui.sameLine(.{});

            const padding = if (8 + i < 10) " " else "";
            zgui.text("{s}R{}: 0x{X:0>8}", .{ padding, 8 + i, cpu.r[8 + i] });
        }

        zgui.separator();

        widgets.psr("CPSR", cpu.cpsr);
        widgets.psr("SPSR", cpu.spsr);

        zgui.separator();

        widgets.interrupts(" IE", bus_ptr.io.ie);
        widgets.interrupts("IRQ", bus_ptr.io.irq);
    }

    if (state.win_stat.show_perf) {
        _ = zgui.begin("Performance", .{ .popen = &state.win_stat.show_perf });
        defer zgui.end();

        const tmp = blk: {
            var buf: [histogram_len]u32 = undefined;
            const len = state.fps_hist.copy(&buf);

            break :blk .{ buf, len };
        };
        const values = tmp[0];
        const len = tmp[1];

        if (len == values.len) _ = state.fps_hist.pop();

        const sorted = blk: {
            var buf: @TypeOf(values) = undefined;

            @memcpy(buf[0..len], values[0..len]);
            std.mem.sort(u32, buf[0..len], {}, std.sort.asc(u32));

            break :blk buf;
        };

        const y_max: f64 = 2 * if (len != 0) @as(f64, @floatFromInt(sorted[len - 1])) else emu.frame_rate;
        const x_max: f64 = @floatFromInt(values.len);

        const y_args = .{ .flags = .{ .no_grid_lines = true } };
        const x_args = .{ .flags = .{ .no_grid_lines = true, .no_tick_labels = true, .no_tick_marks = true } };

        if (zgui.plot.beginPlot("Emulation FPS", .{ .w = 0.0, .flags = .{ .no_title = true, .no_frame = true } })) {
            defer zgui.plot.endPlot();

            zgui.plot.setupLegend(.{ .north = true, .east = true }, .{});
            zgui.plot.setupAxis(.x1, x_args);
            zgui.plot.setupAxis(.y1, y_args);
            zgui.plot.setupAxisLimits(.y1, .{ .min = 0.0, .max = y_max, .cond = .always });
            zgui.plot.setupAxisLimits(.x1, .{ .min = 0.0, .max = x_max, .cond = .always });
            zgui.plot.setupFinish();

            zgui.plot.plotLineValues("FPS", u32, .{ .v = values[0..len] });
        }

        const stats: struct { u32, u32, u32 } = blk: {
            if (len == 0) break :blk .{ 0, 0, 0 };

            const average: u32 = average: {
                var sum: u32 = 0;
                for (sorted[0..len]) |value| sum += value;

                break :average @intCast(sum / len);
            };
            const median = sorted[len / 2];
            const low = sorted[len / 100]; // 1% Low

            break :blk .{ average, median, low };
        };

        zgui.text("Average: {:0>3} fps", .{stats[0]});
        zgui.text(" Median: {:0>3} fps", .{stats[1]});
        zgui.text(" 1% Low: {:0>3} fps", .{stats[2]});
    }

    if (state.win_stat.show_schedule) {
        _ = zgui.begin("Schedule", .{ .popen = &state.win_stat.show_schedule });
        defer zgui.end();

        const scheduler = cpu.sched;

        zgui.text("tick: {X:0>16}", .{scheduler.now()});
        zgui.separator();

        const sched_ptr: *Scheduler = @ptrCast(@alignCast(cpu.sched.ptr));
        const Event = std.meta.Child(@TypeOf(sched_ptr.queue.items));

        var items: [20]Event = undefined;
        const len = @min(sched_ptr.queue.len, items.len);

        @memcpy(items[0..len], sched_ptr.queue.items[0..len]);
        std.mem.sort(Event, items[0..len], {}, widgets.eventDesc(Event));

        for (items[0..len]) |event| {
            zgui.text("{X:0>16} | {?}", .{ event.tick, event.kind });
        }
    }

    if (state.win_stat.show_palette) {
        _ = zgui.begin("Palette", .{ .popen = &state.win_stat.show_palette });
        defer zgui.end();

        widgets.paletteGrid(.Background, cpu);

        zgui.sameLine(.{ .spacing = 20.0 });

        widgets.paletteGrid(.Object, cpu);
    }

    // {
    //     zgui.showDemoWindow(null);
    // }

    return true; // request redraw
}

const widgets = struct {
    const PaletteKind = enum { Background, Object };

    fn paletteGrid(comptime kind: PaletteKind, cpu: *const Arm7tdmi) void {
        _ = zgui.beginGroup();
        defer zgui.endGroup();

        const address: u32 = switch (kind) {
            .Background => 0x0500_0000,
            .Object => 0x0500_0200,
        };

        for (0..0x100) |i| {
            const offset: u32 = @truncate(i);
            const bgr555 = cpu.bus.dbgRead(u16, address + offset * @sizeOf(u16));
            widgets.colourSquare(bgr555);

            if ((i + 1) % 0x10 != 0) zgui.sameLine(.{});
        }
        zgui.text(@tagName(kind), .{});
    }

    fn colourSquare(bgr555: u16) void {
        // FIXME: working with the packed struct enum is currently broken :pensive:
        const ImguiColorEditFlags_NoInputs: u32 = 1 << 5;
        const ImguiColorEditFlags_NoPicker: u32 = 1 << 2;
        const flags: zgui.ColorEditFlags = @bitCast(ImguiColorEditFlags_NoInputs | ImguiColorEditFlags_NoPicker);

        const b: f32 = @floatFromInt(bgr555 >> 10 & 0x1f);
        const g: f32 = @floatFromInt(bgr555 >> 5 & 0x1F);
        const r: f32 = @floatFromInt(bgr555 & 0x1F);

        var col = [_]f32{ r / 31.0, g / 31.0, b / 31.0 };

        _ = zgui.colorEdit3("", .{ .col = &col, .flags = flags });
    }

    fn interrupts(comptime label: []const u8, int: anytype) void {
        const h = 15.0;
        const w = 9.0 * 2 + 3.5;
        const ww = 9.0 * 3;

        {
            zgui.text(label ++ ":", .{});

            zgui.sameLine(.{});
            _ = zgui.selectable("VBL", .{ .w = w, .h = h, .selected = int.vblank.read() });

            zgui.sameLine(.{});
            _ = zgui.selectable("HBL", .{ .w = w, .h = h, .selected = int.hblank.read() });

            zgui.sameLine(.{});
            _ = zgui.selectable("VCT", .{ .w = w, .h = h, .selected = int.coincidence.read() });

            {
                zgui.sameLine(.{});
                _ = zgui.selectable("TIM0", .{ .w = ww, .h = h, .selected = int.tim0.read() });

                zgui.sameLine(.{});
                _ = zgui.selectable("TIM1", .{ .w = ww, .h = h, .selected = int.tim1.read() });

                zgui.sameLine(.{});
                _ = zgui.selectable("TIM2", .{ .w = ww, .h = h, .selected = int.tim2.read() });

                zgui.sameLine(.{});
                _ = zgui.selectable("TIM3", .{ .w = ww, .h = h, .selected = int.tim3.read() });
            }

            zgui.sameLine(.{});
            _ = zgui.selectable("SRL", .{ .w = w, .h = h, .selected = int.serial.read() });

            {
                zgui.sameLine(.{});
                _ = zgui.selectable("DMA0", .{ .w = ww, .h = h, .selected = int.dma0.read() });

                zgui.sameLine(.{});
                _ = zgui.selectable("DMA1", .{ .w = ww, .h = h, .selected = int.dma1.read() });

                zgui.sameLine(.{});
                _ = zgui.selectable("DMA2", .{ .w = ww, .h = h, .selected = int.dma2.read() });

                zgui.sameLine(.{});
                _ = zgui.selectable("DMA3", .{ .w = ww, .h = h, .selected = int.dma3.read() });
            }

            zgui.sameLine(.{});
            _ = zgui.selectable("KPD", .{ .w = w, .h = h, .selected = int.keypad.read() });

            zgui.sameLine(.{});
            _ = zgui.selectable("GPK", .{ .w = w, .h = h, .selected = int.game_pak.read() });
        }
    }

    fn psr(comptime label: []const u8, register: anytype) void {
        const Mode = @import("arm32").arm.Mode;

        const maybe_mode = std.meta.intToEnum(Mode, register.mode.read()) catch null;
        const mode = if (maybe_mode) |mode| mode.toString() else "???";
        const w = 9.0;
        const h = 15.0;

        zgui.text(label ++ ": 0x{X:0>8}", .{register.raw});

        zgui.sameLine(.{});
        _ = zgui.selectable("N", .{ .w = w, .h = h, .selected = register.n.read() });

        zgui.sameLine(.{});
        _ = zgui.selectable("Z", .{ .w = w, .h = h, .selected = register.z.read() });

        zgui.sameLine(.{});
        _ = zgui.selectable("C", .{ .w = w, .h = h, .selected = register.c.read() });

        zgui.sameLine(.{});
        _ = zgui.selectable("V", .{ .w = w, .h = h, .selected = register.v.read() });

        zgui.sameLine(.{});
        zgui.text("{s}", .{mode});
    }

    fn eventDesc(comptime T: type) fn (void, T, T) bool {
        return struct {
            fn inner(_: void, left: T, right: T) bool {
                return left.tick > right.tick;
            }
        }.inner;
    }
};

fn handleTitle(title_opt: ?*const [12]u8) [12:0]u8 {
    if (title_opt == null) return "[N/A Title]\x00".*; // No ROM present
    const title = title_opt.?;

    // ROM Title is an empty string (ImGui hates these)
    if (title[0] == '\x00') return "[No Title]\x00\x00".*;

    return title.* ++ [_:0]u8{};
}
