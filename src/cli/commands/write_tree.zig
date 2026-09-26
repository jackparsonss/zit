const std = @import("std");

const ObjectId = @import("common").objects.ObjectId;
const Object = @import("common").objects.Object;
const Tree = @import("common").objects.Tree;
const Context = @import("../context.zig");

const logger = @import("common").logger;

pub fn run(ctx: Context, _: []const []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    const root_dir = try cwd.openDir(ctx.io, ".", .{ .iterate = true });
    defer root_dir.close(ctx.io);

    const tree = try Tree.initFromDir(ctx.allocator, ctx.io, root_dir);
    if (tree == null) {
        logger.err("Failed to write tree", .{});
    }

    const obj = Object{ .tree = tree.? };
    const id = try obj.get_id(ctx.allocator);
    try logger.log(ctx.io, "{s}\n", .{try id.format(ctx.allocator)});
}
