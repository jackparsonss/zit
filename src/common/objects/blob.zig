const std = @import("std");

const Blob = @This();

file_content: []const u8,

pub fn init(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Blob {
    const dir = try std.Io.Dir.cwd().openDir(io, ".", .{});
    const file_content = try dir.readFileAlloc(io, path, allocator, .unlimited);

    return .{ .file_content = file_content };
}

pub fn initFromBytes(bytes: []const u8) !Blob {
    const null_idx = std.mem.indexOfScalar(u8, bytes, '\x00');
    if (null_idx == null) {
        return error.InvalidBlobHeader;
    }

    const size_t = bytes[0..null_idx.?];
    const size = try std.fmt.parseInt(usize, size_t, 10);
    if (size != bytes[null_idx.? + 1 ..].len) {
        return error.InvalidBlobHeaderSize;
    }

    const file_content = bytes[null_idx.? + 1 ..];
    return .{ .file_content = file_content };
}

pub fn header(self: Blob, allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "blob {d}\x00{s}", .{ self.file_content.len, self.file_content });
}
