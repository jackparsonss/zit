const std = @import("std");

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
        }

        return error.UnsupportedObjectType;
    }

    pub fn get_header(self: Object, allocator: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .blob => |b| b.header(allocator),
            .tree => error.TreeUnimplmeneted,
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

    pub fn get_size(self: Object) usize {
        return switch (self) {
            .blob => |b| b.file_content.len,
            .tree => error.TreeUnimplmeneted,
        };
    }

    pub fn get_content(self: Object) []const u8 {
        return switch (self) {
            .blob => |b| b.file_content,
            .tree => error.TreeUnimplmeneted,
        };
    }
};
