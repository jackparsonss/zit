const std = @import("std");

const obj = @import("common").objects;
const logger = @import("common").logger;

const Context = @import("../context.zig");

pub fn run(ctx: Context, args: []const []const u8) !void {
    if (args.len != 1) {
        logger.err("hash-object requires exactly one argument", .{});
        return;
    }

    const file_path = args[0];
    const blob = try obj.Blob.init(ctx.allocator, ctx.io, file_path);
    const object = obj.Object{ .blob = blob };

    const id = try object.get_id(ctx.allocator);
    defer id.deinit(ctx.allocator);

    const hash = try id.format(ctx.allocator);
    defer ctx.allocator.free(hash);

    std.debug.print("{s}\n", .{hash});
}
