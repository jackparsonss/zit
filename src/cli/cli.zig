const build_options = @import("build_options");
const std = @import("std");

pub fn parse(args: []const []const u8) !void {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--version")) {
            std.debug.print("Version: {s}\n", .{build_options.version});
            return;
        }
    }
}
