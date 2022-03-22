const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.Backup);

const correctTitle = @import("../util.zig").correctTitle;
const safeTitle = @import("../util.zig").safeTitle;

const backup_kinds = [5]Needle{
    .{ .str = "EEPROM_V", .kind = .Eeprom },
    .{ .str = "SRAM_V", .kind = .Sram },
    .{ .str = "FLASH_V", .kind = .Flash },
    .{ .str = "FLASH512_V", .kind = .Flash },
    .{ .str = "FLASH1M_V", .kind = .Flash1M },
};

pub const Backup = struct {
    const Self = @This();

    buf: []u8,
    alloc: Allocator,
    kind: BackupKind,

    title: [12]u8,
    save_path: ?[]const u8,

    pub fn init(alloc: Allocator, kind: BackupKind, title: [12]u8, path: ?[]const u8) !Self {
        const buf_len: usize = switch (kind) {
            .Sram => 0x8000, // 32K
            .Flash => 0x10000, // 64K
            .Flash1M => 0x20000, // 128K
            .Eeprom => 0x2000, // FIXME: We assume 8K here
        };

        const buf = try alloc.alloc(u8, buf_len);
        std.mem.set(u8, buf, 0);

        var backup = Self{
            .buf = buf,
            .alloc = alloc,
            .kind = kind,
            .title = title,
            .save_path = path,
        };
        if (backup.save_path) |p| backup.loadSaveFromDisk(p) catch |e| log.err("Failed to load save: {}", .{e});

        return backup;
    }

    pub fn guessKind(rom: []const u8) ?BackupKind {
        @setRuntimeSafety(false);

        for (backup_kinds) |needle| {
            const needle_len = needle.str.len;

            var i: usize = 0;
            while ((i + needle_len) < rom.len) : (i += 1) {
                if (std.mem.eql(u8, needle.str, rom[i..][0..needle_len])) return needle.kind;
            }
        }

        return null;
    }

    pub fn deinit(self: Self) void {
        if (self.save_path) |path| self.writeSaveToDisk(path) catch |e| log.err("Failed to write save: {}", .{e});

        self.alloc.free(self.buf);
    }

    fn loadSaveFromDisk(self: *Self, path: []const u8) !void {
        const file_path = try self.getSaveFilePath(path);
        defer self.alloc.free(file_path);

        const file: std.fs.File = try std.fs.openFileAbsolute(file_path, .{});

        const len = try file.getEndPos();
        const file_buf = try file.readToEndAlloc(self.alloc, len);
        defer self.alloc.free(file_buf);

        switch (self.kind) {
            .Sram => {
                std.mem.copy(u8, self.buf, file_buf);
                log.info("Loaded Save from {s}", .{file_path});
            },
            else => return SaveError.UnsupportedBackupKind,
        }
    }

    fn getSaveFilePath(self: *const Self, path: []const u8) ![]const u8 {
        const filename = try self.getSaveFilename();
        defer self.alloc.free(filename);

        return try std.fs.path.join(self.alloc, &[_][]const u8{ path, filename });
    }

    fn getSaveFilename(self: *const Self) ![]const u8 {
        const title = correctTitle(safeTitle(self.title));
        return try std.mem.concat(self.alloc, u8, &[_][]const u8{ title, ".sav" });
    }

    fn writeSaveToDisk(self: Self, path: []const u8) !void {
        const file_path = try self.getSaveFilePath(path);
        defer self.alloc.free(file_path);

        switch (self.kind) {
            .Sram => {
                const file = try std.fs.createFileAbsolute(file_path, .{});
                defer file.close();

                try file.writeAll(self.buf);
                log.info("Dumped SRAM to {s}", .{file_path});
            },
            else => return SaveError.UnsupportedBackupKind,
        }
    }

    pub fn get8(self: *const Self, idx: usize) u8 {
        // TODO: Implement Flash and EEPROM
        switch (self.kind) {
            .Flash => return switch (idx) {
                0x0000 => 0x32, // Panasonic manufacturer ID
                0x0001 => 0x1B, // Panasonic device ID
                else => self.buf[idx],
            },
            .Flash1M => return switch (idx) {
                0x0000 => 0x62, // Sanyo manufacturer ID
                0x0001 => 0x13, // Sanyo device ID
                else => self.buf[idx],
            },
            .Eeprom => return self.buf[idx],
            .Sram => return self.buf[idx & 0x7FFF], // 32K SRAM chips are repeated
        }
    }

    pub fn set8(self: *Self, idx: usize, byte: u8) void {
        self.buf[idx] = byte;
    }
};

const BackupKind = enum {
    Eeprom,
    Sram,
    Flash,
    Flash1M,
};

const Needle = struct {
    str: []const u8,
    kind: BackupKind,

    fn init(str: []const u8, kind: BackupKind) @This() {
        return .{
            .str = str,
            .kind = kind,
        };
    }
};

const SaveError = error{
    UnsupportedBackupKind,
};
