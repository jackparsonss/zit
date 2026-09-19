const std = @import("std");

const logger = @import("common").logger;

const Context = @import("../context.zig");

const ParsedArgs = struct {
    file_path: []const u8,
    t_flag: bool = false,
    s_flag: bool = false,
    p_flag: bool = false,
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
        if (std.mem.eql(u8, arg, "-t")) {
            parsed_args.t_flag = true;
        } else if (std.mem.eql(u8, arg, "-s")) {
            parsed_args.s_flag = true;
        } else if (std.mem.eql(u8, arg, "-p")) {
            parsed_args.p_flag = true;
        }
    }
}
