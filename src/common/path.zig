const std = @import("std");

const constants = @import("constants.zig");

pub fn findRootDir(io: std.Io) !std.Io.Dir {
    var dir = try std.Io.Dir.cwd().openDir(io, ".", .{});
    while (true) {
        if (dir.access(io, constants.ROOT_DIR, .{})) |_| return dir else |err| {
            if (err != error.FileNotFound) {
                return err;
            }
        }

        const parent = try dir.openDir(io, "..", .{});
        const at_fs_root = (try dir.stat(io)).inode == (try parent.stat(io)).inode;
        dir.close(io);

        if (at_fs_root) {
            parent.close(io);
            return error.RootDirNotFound;
        }
        dir = parent;
    }
}
