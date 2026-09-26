const build_options = @import("build_options");
const std = @import("std");

const logger = @import("common").logger;

const hash_object = @import("commands/hash_object.zig");
const write_tree = @import("commands/write_tree.zig");
const cat_file = @import("commands/cat_file.zig");
const init = @import("commands/init.zig");
const Context = @import("context.zig");

const Command = enum {
    hash_object,
    write_tree,
    cat_file,
    version,
    init,

    pub fn run(self: Command, ctx: Context, args: []const []const u8) !void {
        logger.debug("Running command: {s}", .{@tagName(self)});
        switch (self) {
            .hash_object => try hash_object.run(ctx, args),
            .write_tree => try write_tree.run(ctx, args),
            .cat_file => try cat_file.run(ctx, args),
            .version => std.debug.print("Version: {s}\n", .{build_options.version}),
            .init => try init.run(ctx),
        }
    }
};

pub fn parse(args: []const []const u8, ctx: Context) !void {
    if (args.len == 0) {
        std.debug.print("No arguments provided\n", .{});
        return;
    }

    const rawArg = if (std.mem.startsWith(u8, args[0], "--")) args[0][2..] else args[0];
    var arg_buf: [256]u8 = undefined;
    const parsedArg = if (rawArg.len <= arg_buf.len) blk: {
        const normalized = arg_buf[0..rawArg.len];
        @memcpy(normalized, rawArg);
        std.mem.replaceScalar(u8, normalized, '-', '_');
        break :blk normalized;
    } else rawArg;

    const cmd = std.meta.stringToEnum(Command, parsedArg);
    if (cmd == null) {
        std.debug.print("Unknown command: {s}\n", .{parsedArg});
        return;
    }

    try cmd.?.run(ctx, args[1..]);
}
