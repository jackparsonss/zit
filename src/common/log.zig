const builtin = @import("builtin");
const std = @import("std");

const log = std.log.scoped(.zit);

pub fn err(comptime format: []const u8, args: anytype) void {
    if (comptime builtin.is_test) return;
    log.err(format, args);
}

pub fn warn(comptime format: []const u8, args: anytype) void {
    if (comptime builtin.is_test) return;
    log.warn(format, args);
}

pub fn info(comptime format: []const u8, args: anytype) void {
    log.info(format, args);
}

pub fn debug(comptime format: []const u8, args: anytype) void {
    log.debug(format, args);
}
