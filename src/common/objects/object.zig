const std = @import("std");
const flate = std.compress.flate;

const constants = @import("../constants.zig");
const path = @import("../path.zig");

pub const Blob = @import("blob.zig");
pub const Tree = @import("tree.zig");

pub const ObjectId = struct {
    id: []const u8,

    pub fn init(allocator: std.mem.Allocator, object_header: []const u8) !ObjectId {
        var hasher = std.crypto.hash.Sha1.init(.{});
        hasher.update(object_header);

        var bytes: [20]u8 = undefined;
        hasher.final(&bytes);

        return .{ .id = try allocator.dupe(u8, &bytes) };
    }

    pub fn format(self: ObjectId, allocator: std.mem.Allocator) ![]const u8 {
        const hex_digits = std.fmt.bytesToHex(self.id[0..20].*, .lower);
        return allocator.dupe(u8, &hex_digits);
    }

    pub fn deinit(self: ObjectId, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
    }
};

pub const Object = union(enum) {
    blob: Blob,
    tree: Tree,

    pub fn initFromBytes(bytes: []const u8) !Object {
        const type_idx = std.mem.indexOfScalar(u8, bytes, ' ');
        if (type_idx == null) {
            return error.InvalidObjectHeader;
        }

        const type_name = bytes[0..type_idx.?];
        if (std.mem.eql(u8, type_name, "blob")) {
            return .{ .blob = try Blob.initFromBytes(bytes[type_idx.? + 1 ..]) };
        } else if (std.mem.eql(u8, type_name, "tree")) {
            return .{ .tree = try Tree.initFromBytes(bytes[type_idx.? + 1 ..]) };
        }

        return error.UnsupportedObjectType;
    }

    pub fn get_header(self: Object, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .blob => |b| b.header(allocator),
            .tree => |t| t.header(allocator),
        };
    }

    pub fn get_id(self: Object, allocator: std.mem.Allocator) !ObjectId {
        const header = try self.get_header(allocator);
        defer allocator.free(header);

        return try ObjectId.init(allocator, header);
    }

    pub fn get_type(self: Object) []const u8 {
        return switch (self) {
            .blob => "blob",
            .tree => "tree",
        };
    }

    pub fn get_size(self: Object, allocator: std.mem.Allocator) !usize {
        return switch (self) {
            .blob => |b| b.file_content.len,
            .tree => |t| {
                const content = try t.content(allocator);
                return content.len;
            },
        };
    }

    pub fn get_content(self: Object, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .blob => |b| b.file_content,
            .tree => |t| t.content(allocator),
        };
    }

    pub fn writeObject(self: Object, allocator: std.mem.Allocator, io: std.Io, hash: []const u8) !void {
        const base = hash[0..2];
        const base_path = try std.mem.concat(allocator, u8, &.{ constants.OBJECTS_DIR, "/", base });
        defer allocator.free(base_path);
        const obj_path = hash[2..];

        const root_dir = try path.findRootDir(io);
        defer root_dir.close(io);

        const base_dir = root_dir.openDir(io, base_path, .{}) catch |err| blk: {
            if (err != error.FileNotFound) {
                return err;
            }

            try root_dir.createDirPath(io, base_path);
            break :blk try root_dir.openDir(io, base_path, .{});
        };
        defer base_dir.close(io);

        if (base_dir.openFile(io, obj_path, .{})) |existing| {
            // return early if file already exists
            existing.close(io);
            return;
        } else |err| {
            if (err != error.FileNotFound) {
                return err;
            }
        }

        var file = try base_dir.createFileAtomic(io, obj_path, .{});

        var file_buf: [4096]u8 = undefined;
        var file_writer = file.file.writer(io, &file_buf);
        const writer = &file_writer.interface;

        const window = try allocator.alloc(u8, flate.max_window_len);
        defer allocator.free(window);

        var z = try flate.Compress.init(writer, window, .zlib, .fastest);

        const header = try self.get_header(allocator);
        defer allocator.free(header);

        try z.writer.writeAll(header);
        try z.finish();
        try writer.flush();

        try file.link(io);
    }
};
