const std = @import("std");

const obj = @import("common").objects;
const logger = @import("common").logger;

const Context = @import("../context.zig");

const ParsedArgs = struct {
    file_path: []const u8,
    w_flag: bool = false,
};

pub fn run(ctx: Context, args: []const []const u8) !void {
    if (args.len == 0) {
        logger.err("hash-object requires at least one argument", .{});
        return;
    }
    var parsed_args = ParsedArgs{
        .file_path = args[0],
    };

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "-w")) {
            parsed_args.w_flag = true;
        }
    }

    const blob = try obj.Blob.init(ctx.allocator, ctx.io, parsed_args.file_path);
    const object = obj.Object{ .blob = blob };

    const id = try object.get_id(ctx.allocator);
    defer id.deinit(ctx.allocator);

    const hash = try id.format(ctx.allocator);
    defer ctx.allocator.free(hash);

    if (parsed_args.w_flag) {}

    try logger.log(ctx.io, "{s}\n", .{hash});
}
