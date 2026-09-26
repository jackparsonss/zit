const std = @import("std");

const constants = @import("common").constants;
const logger = @import("common").logger;

const Context = @import("../context.zig");

pub fn run(ctx: Context) !void {
    const base_paths = [_][]const u8{
        constants.ROOT_DIR,
        constants.OBJECTS_DIR,
        constants.HEADS_DIR,
        constants.TAGS_DIR,
    };

    const cwd = std.Io.Dir.cwd();
    inline for (base_paths) |dir| {
        cwd.createDirPath(ctx.io, dir) catch |err| {
            logger.err("Failed to create {s} directory: {}", .{ dir, err });
            return;
        };
    }

    const headFile = cwd.createFile(ctx.io, constants.HEAD_FILE, .{}) catch |err| {
        logger.err("Failed to create HEAD file: {}", .{err});
        return;
    };

    var buffer: [4096]u8 = undefined;
    var writer_handle = headFile.writer(ctx.io, &buffer);
    const writer = &writer_handle.interface;
    try writer.writeAll("ref: refs/head/main\n");
    try writer.flush();

    try logger.log(ctx.io, "Initialized empty {s} repository\n", .{constants.ROOT_DIR});
}
