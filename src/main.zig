const std = @import("std");
const cli = @import("cli");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    try cli.parse(args);
}
