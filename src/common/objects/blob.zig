const std = @import("std");

const Blob = @This();

file_content: []const u8,

pub fn init(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Blob {
    const dir = try std.Io.Dir.cwd().openDir(io, ".", .{});
    const file_content = try dir.readFileAlloc(io, path, allocator, .unlimited);

    return .{ .file_content = file_content };
}

pub fn header(self: Blob, allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "blob {d}\x00{s}", .{ self.file_content.len, self.file_content });
}
