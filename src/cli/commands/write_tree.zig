const std = @import("std");

const ObjectId = @import("common").objects.ObjectId;
const Object = @import("common").objects.Object;
const constants = @import("common").constants;
const Tree = @import("common").objects.Tree;
const Context = @import("../context.zig");
const path = @import("common").path;

const logger = @import("common").logger;

pub fn run(ctx: Context, _: []const []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    const root_dir = try cwd.openDir(ctx.io, ".", .{ .iterate = true });
    defer root_dir.close(ctx.io);

    const tree = try Tree.initFromDir(ctx.allocator, ctx.io, root_dir);
    if (tree == null) {
        logger.err("Failed to write tree", .{});
        return;
    }

    const obj = Object{ .tree = tree.? };
    const id = try obj.get_id(ctx.allocator);

    const hash = try id.format(ctx.allocator);
    try logger.log(ctx.io, "{s}\n", .{hash});

    try obj.writeObject(ctx.allocator, ctx.io, hash);
}
