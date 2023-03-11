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
const Arm7tdmi = @import("core/cpu.zig").Arm7tdmi;
const RingBuffer = @import("zba-util").RingBuffer;

const Allocator = std.mem.Allocator;
const GLuint = gl.GLuint;

const gba_width = @import("core/ppu.zig").width;
const gba_height = @import("core/ppu.zig").height;

const log = std.log.scoped(.Imgui);

// TODO: Document how I decided on this value (I forgot 😅)
const histogram_len = 0x400;

/// Immediate-Mode GUI State
pub const State = struct {
    title: [12:0]u8,

    fps_hist: RingBuffer(u32),
    should_quit: bool = false,

    pub fn init(allocator: Allocator) !@This() {
        const history = try allocator.alloc(u32, histogram_len);

        var title: [12:0]u8 = [_:0]u8{0} ** 12;
        std.mem.copy(u8, &title, "[No Title]");

        return .{
            .title = title,
            .fps_hist = RingBuffer(u32).init(history),
        };
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        allocator.free(self.fps_hist.buf);
        self.* = undefined;
    }
};

pub fn draw(state: *State, tex_id: GLuint, cpu: *Arm7tdmi) void {
    const win_scale = config.config().host.win_scale;

    {
        _ = zgui.beginMainMenuBar();
        defer zgui.endMainMenuBar();

        if (zgui.beginMenu("File", true)) {
            defer zgui.endMenu();

            if (zgui.menuItem("Quit", .{})) state.should_quit = true;

            if (zgui.menuItem("Insert ROM", .{})) blk: {
                const maybe_path = nfd.openFileDialog("gba", null) catch |e| {
                    log.err("failed to open file dialog: {}", .{e});
                    break :blk;
                };

                if (maybe_path) |file_path| {
                    defer nfd.freePath(file_path);
                    log.info("user chose: \"{s}\"", .{file_path});

                    emu.replaceGamepak(cpu, file_path) catch |e| {
                        log.err("failed to replace GamePak: {}", .{e});
                        break :blk;
                    };

                    // Ideally, state.title = cpu.bus.pak.title
                    // since state.title is a [12:0]u8 and cpu.bus.pak.title is a [12]u8
                    std.mem.copy(u8, &state.title, &cpu.bus.pak.title);
                }
            }
        }

        if (zgui.beginMenu("Emulation", true)) {
            defer zgui.endMenu();

            if (zgui.menuItem("Restart", .{})) {
                emu.reset(cpu);
            }
        }
    }

    {
        const w = @intToFloat(f32, gba_width * win_scale);
        const h = @intToFloat(f32, gba_height * win_scale);

        const window_title = std.mem.sliceTo(&state.title, 0);
        _ = zgui.begin(window_title, .{ .flags = .{ .no_resize = true, .always_auto_resize = true } });
        defer zgui.end();

        zgui.image(@intToPtr(*anyopaque, tex_id), .{ .w = w, .h = h, .uv0 = .{ 0, 1 }, .uv1 = .{ 1, 0 } });
    }

    {
        _ = zgui.begin("Information", .{});
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

        widgets.interrupts(" IE", cpu.bus.io.ie);
        widgets.interrupts("IRQ", cpu.bus.io.irq);
    }

    {
        _ = zgui.begin("Performance", .{});
        defer zgui.end();

        const tmp = blk: {
            var buf: [0x400]u32 = undefined;
            const len = state.fps_hist.copy(&buf);

            break :blk .{ buf, len };
        };
        const values = tmp[0];
        const len = tmp[1];

        if (len == values.len) _ = state.fps_hist.pop();

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
    }

    {
        _ = zgui.begin("Scheduler", .{});
        defer zgui.end();

        const scheduler = cpu.sched;

        zgui.text("tick: {X:0>16}", .{scheduler.tick});
        zgui.separator();

        const Event = std.meta.Child(@TypeOf(scheduler.queue.items));

        var items: [20]Event = undefined;
        const len = scheduler.queue.len;

        std.mem.copy(Event, &items, scheduler.queue.items);
        std.sort.sort(Event, items[0..len], {}, widgets.eventDesc(Event));

        for (items[0..len]) |event| {
            zgui.text("{X:0>16} | {?}", .{ event.tick, event.kind });
        }
    }

    // {
    //     zgui.showDemoWindow(null);
    // }
}

const widgets = struct {
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
        const Mode = @import("core/cpu.zig").Mode;

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
