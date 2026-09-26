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
        // TODO: pick proper mode
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
        } else {
            obj = .{ .blob = try Blob.initFromDir(allocator, io, dir, entry.name) };
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

    const ctx = Context{ .allocator = allocator };
    std.mem.sort(Entry, entries.items, ctx, sort_entry);

    return .{
        .entries = try entries.toOwnedSlice(allocator),
    };
}

const Context = struct {
    allocator: std.mem.Allocator,
};

// follow git's pattern of directories sorting based on name with an appending "/"
fn sort_entry(ctx: Context, a: Entry, b: Entry) bool {
    const a_name = if (a.mode == .directory) std.mem.concat(ctx.allocator, u8, &.{ a.name, "/" }) catch {
        return false;
    } else a.name;
    const b_name = if (b.mode == .directory) std.mem.concat(ctx.allocator, u8, &.{ b.name, "/" }) catch {
        return false;
    } else b.name;
    return std.mem.lessThan(u8, a_name, b_name);
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

    pub fn parse(bytes: []const u8) !Entry {
        const mode_str = bytes[0..5];
        if (std.mem.eql(u8, mode_str, "100644")) {
            return .file;
        } else if (std.mem.eql(u8, mode_str, "120000")) {
            return .symlink;
        } else if (std.mem.eql(u8, mode_str, "40000")) {
            return .directory;
        } else if (std.mem.eql(u8, mode_str, "160000")) {
            return .submodule;
        } else if (std.mem.eql(u8, mode_str, "100755")) {
            return .executable;
        } else {
            return error.InvalidMode;
        }
    }

    pub fn str(self: Mode) []const u8 {
        return switch (self) {
            .file => "100644",
            .symlink => "120000",
            .directory => "040000",
            .submodule => "160000",
            .executable => "100755",
        };
    }
};

const Entry = struct {
    mode: Mode,
    name: []const u8,
    object_id: ObjectId,

    pub fn parse(bytes: []const u8) !Entry {
        const mode_idx = std.mem.indexOfScalar(u8, bytes, ' ');
        if (mode_idx == null) {
            return error.InvalidMode;
        }

        const mode_str = bytes[0..mode_idx.?];
        const mode = try Mode.parse(mode_str);

        const name_idx = std.mem.indexOfScalar(u8, bytes[mode_idx.?..], '\x00');
        if (name_idx == null) {
            return error.InvalidName;
        }
        const name = bytes[mode_idx.?..name_idx.?];

        if (bytes[name_idx.?..].len != 20) {
            return error.InvalidObjectId;
        }

        const object_id = ObjectId{ .id = bytes[name_idx.?..] };

        return .{
            .mode = mode,
            .name = name,
            .object_id = object_id,
        };
    }

    pub fn toBytes(self: Entry, allocator: std.mem.Allocator) ![]const u8 {
        const mode = self.mode.str();
        const id = self.object_id.id;

        return try std.fmt.allocPrint(allocator, "{s} {s}\x00{s}", .{ mode, self.name, id });
    }
};
