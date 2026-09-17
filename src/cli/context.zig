const std = @import("std");

const Context = @This();

allocator: std.mem.Allocator,
io: std.Io,
