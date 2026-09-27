const std = @import("std");

const ObjectId = @import("object.zig").ObjectId;
const Object = @import("object.zig").Object;
const logger = @import("../log.zig");
const Blob = @import("blob.zig");

const Tree = @This();

entries: []Entry,

pub fn initFromDir(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir) !?Tree {
    var entries: std.ArrayList(Entry) = .empty;
    defer entries.deinit(allocator);

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (std.mem.eql(u8, entry.name, ".zit") or std.mem.eql(u8, entry.name, ".git")) {
            continue;
        }

        var mode: Mode = .file;

        var obj: Object = undefined;
        if (entry.kind == .directory) {
            const sub_dir = try dir.openDir(io, entry.name, .{ .iterate = true });
            defer sub_dir.close(io);

            const sub_tree = try initFromDir(allocator, io, sub_dir);
            if (sub_tree == null) {
                continue;
            }

            obj = .{ .tree = sub_tree.? };
            mode = .directory;
        } else if (entry.kind == .sym_link) {
            mode = .symlink;
            var buffer: [std.fs.max_path_bytes]u8 = undefined;
            const target_size = try dir.readLink(io, entry.name, &buffer);
            obj = .{ .blob = Blob{ .file_content = try allocator.dupe(u8, buffer[0..target_size]) } };
        } else {
            const file = try dir.openFile(io, entry.name, .{ .follow_symlinks = false });
            defer file.close(io);

            var reader_handle = file.reader(io, &.{});
            const reader = &reader_handle.interface;

            const stat = try file.stat(io);
            const md = stat.permissions.toMode();
            if (md & 0o100 != 0) {
                mode = .executable;
            }

            const file_content = try reader.allocRemaining(allocator, .unlimited);
            obj = .{ .blob = Blob{ .file_content = file_content } };
        }

        const blob_header = try obj.get_header(allocator);
        const id = try ObjectId.init(allocator, blob_header);

        try entries.append(allocator, .{
            .name = try allocator.dupe(u8, entry.name),
            .object_id = id,
            .mode = mode,
        });
    }

    if (entries.items.len == 0) {
        return null;
    }
    std.mem.sort(Entry, entries.items, {}, sort_entry);

    return .{
        .entries = try entries.toOwnedSlice(allocator),
    };
}

pub fn initFromBytes(allocator: std.mem.Allocator, bytes: []const u8) !Tree {
    const entries: std.ArrayList(Entry) = .empty;
    var rest = bytes;
    while (rest.len > 0) {
        try entries.append(allocator, try Entry.parse(&rest));
    }

    return .{
        .entries = try entries.toOwnedSlice(allocator),
    };
}

fn sort_entry(_: void, a: Entry, b: Entry) bool {
    const i = std.mem.indexOfDiff(u8, a.name, b.name) orelse return false;
    return sort_byte(a, i) < sort_byte(b, i);
}

fn sort_byte(entry: Entry, i: usize) u8 {
    if (i < entry.name.len) return entry.name[i];
    return if (entry.mode == .directory) '/' else 0;
}

pub fn header(self: Tree, allocator: std.mem.Allocator) ![]const u8 {
    var entries: std.ArrayList(u8) = .empty;
    defer entries.deinit(allocator);

    for (self.entries) |entry| {
        const bytes = try entry.toBytes(allocator);
        try entries.appendSlice(allocator, bytes);
        allocator.free(bytes);
    }

    return try std.fmt.allocPrint(allocator, "tree {d}\x00{s}", .{ entries.items.len, entries.items });
}

pub fn content(self: Tree, allocator: std.mem.Allocator) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);

    for (self.entries) |entry| {
        const bytes = try entry.toBytes(allocator);
        try result.appendSlice(allocator, bytes);
        allocator.free(bytes);
    }

    return result.toOwnedSlice(allocator);
}

const Mode = enum(u32) {
    file = 100644,
    symlink = 120000,
    directory = 4000,
    submodule = 160000,
    executable = 100755,

    pub fn parse(bytes: []const u8) !Mode {
        if (std.mem.eql(u8, bytes, "100644")) {
            return .file;
        } else if (std.mem.eql(u8, bytes, "120000")) {
            return .symlink;
        } else if (std.mem.eql(u8, bytes, "40000")) {
            return .directory;
        } else if (std.mem.eql(u8, bytes, "160000")) {
            return .submodule;
        } else if (std.mem.eql(u8, bytes, "100755")) {
            return .executable;
        } else {
            return error.InvalidMode;
        }
    }

    pub fn str(self: Mode) []const u8 {
        return switch (self) {
            .file => "100644",
            .symlink => "120000",
            .directory => "40000",
            .submodule => "160000",
            .executable => "100755",
        };
    }
};

const Entry = struct {
    mode: Mode,
    name: []const u8,
    object_id: ObjectId,

    pub fn parse(bytes: *[]const u8) !Entry {
        const buf = bytes.*;

        const mode_idx = std.mem.indexOfScalar(u8, buf, ' ') orelse return error.InvalidMode;
        const mode = try Mode.parse(buf[0..mode_idx]);

        const name_idx = std.mem.indexOfScalarPos(u8, buf, mode_idx + 1, '\x00') orelse return error.InvalidName;
        const name = buf[mode_idx + 1 .. name_idx];

        const id_start = name_idx + 1;
        const id_end = id_start + 20;
        if (buf.len < id_end) {
            return error.InvalidObjectId;
        }

        bytes.* = buf[id_end..];
        return .{
            .mode = mode,
            .name = name,
            .object_id = ObjectId{ .id = buf[id_start..id_end] },
        };
    }

    pub fn toBytes(self: Entry, allocator: std.mem.Allocator) ![]const u8 {
        const mode = self.mode.str();
        const id = self.object_id.id;

        return try std.fmt.allocPrint(allocator, "{s} {s}\x00{s}", .{ mode, self.name, id });
    }
};
