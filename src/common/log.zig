const builtin = @import("builtin");
const std = @import("std");

const logger = std.log.scoped(.zit);

pub fn log(io: std.Io, comptime format: []const u8, args: anytype) !void {
    var buffer: [64]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print(format, args);
    try stdout.flush();
}

pub fn err(comptime format: []const u8, args: anytype) void {
    if (comptime builtin.is_test) return;
    logger.err(format, args);
}

pub fn warn(comptime format: []const u8, args: anytype) void {
    if (comptime builtin.is_test) return;
    logger.warn(format, args);
}

pub fn info(comptime format: []const u8, args: anytype) void {
    logger.info(format, args);
}

pub fn debug(comptime format: []const u8, args: anytype) void {
    logger.debug(format, args);
}
