const std = @import("std");

const ObjectId = @import("object.zig").ObjectId;

const Tree = @This();

entries: []Entry,

pub fn initFromDir(io: std.Io, dir: std.Io.Dir) !Tree {
    _ = io;
    _ = dir;
}

pub fn header(self: Tree, allocator: std.mem.Allocator) ![]const u8 {}

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
        } else if (std.mem.eql(u8, mode_str, "040000")) {
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
};
