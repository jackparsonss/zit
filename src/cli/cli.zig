const build_options = @import("build_options");
const logger = @import("common").logger(.cli);
const std = @import("std");

const init = @import("commands/init.zig");

const Command = enum {
    version,
    init,

    pub fn run(self: Command) !void {
        logger.debug("Running command: {s}", .{@tagName(self)});
        switch (self) {
            .version => std.debug.print("Version: {s}\n", .{build_options.version}),
            .init => try init.run(),
        }
    }
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

    try cmd.?.run();
}
