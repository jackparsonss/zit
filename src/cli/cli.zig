const build_options = @import("build_options");
const std = @import("std");

const Command = enum {
    version,
};

pub fn parse(args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("No arguments provided\n", .{});
        return;
    }

    const parsedArg = if (std.mem.startsWith(u8, args[0], "--")) args[0][2..] else args[0];
    const cmd = std.meta.stringToEnum(Command, parsedArg);
    if (cmd == null) {
        std.debug.print("Unknown command: {s}\n", .{parsedArg});
        return;
    }

    switch (cmd.?) {
        .version => std.debug.print("Version: {s}\n", .{build_options.version}),
    }
}
