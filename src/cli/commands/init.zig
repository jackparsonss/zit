const std = @import("std");
const constants = @import("common").constants;
const logger = @import("common").logger(.cli);

const Context = @import("../context.zig");

pub fn run(ctx: Context) void {
    const cwd = std.Io.Dir.cwd();
    inline for ([_][]const u8{ constants.ROOT_DIR, constants.OBJECTS_DIR, constants.HEADS_DIR, constants.TAGS_DIR }) |dir| {
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
    writer.writeAll("ref: refs/head/main\n") catch |err| {
        logger.err("Failed to write to HEAD file: {}", .{err});
        return;
    };
    writer.flush() catch |err| {
        logger.err("Failed to flush HEAD file: {}", .{err});
        return;
    };

    logger.info("Initialized {s} repository", .{constants.ROOT_DIR});
}
