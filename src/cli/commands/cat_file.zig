const std = @import("std");
const flate = std.compress.flate;

const constants = @import("common").constants;
const logger = @import("common").logger;
const obj = @import("common").objects;
const path = @import("common").path;

const Context = @import("../context.zig");

const ParsedArgs = struct {
    file_path: []const u8,
    t_flag: bool = false,
    s_flag: bool = false,
    p_flag: bool = false,
};

pub fn run(ctx: Context, args: []const []const u8) !void {
    if (args.len == 0) {
        logger.err("cat-file requires at least one argument", .{});
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

    const object = try readObject(ctx, parsed_args.file_path);
    if (parsed_args.t_flag) {
        try logger.log(ctx.io, "{s}\n", .{object.get_type()});
    } else if (parsed_args.s_flag) {
        try logger.log(ctx.io, "{}\n", .{object.get_size()});
    } else if (parsed_args.p_flag) {
        try logger.log(ctx.io, "{s}", .{try object.get_content(ctx.allocator)});
    }
}

fn readObject(ctx: Context, id: []const u8) !obj.Object {
    const id_root = id[0..2];
    const id_path = id[2..];

    const full_path = try std.mem.concat(
        ctx.allocator,
        u8,
        &.{ constants.OBJECTS_DIR, "/", id_root, "/", id_path },
    );

    const root_dir = try path.findRootDir(ctx.io);
    defer root_dir.close(ctx.io);

    const file = try root_dir.openFile(ctx.io, full_path, .{});
    defer file.close(ctx.io);

    var read_buf: [4096]u8 = undefined;
    var reader_handle = file.reader(ctx.io, &read_buf);
    const reader = &reader_handle.interface;

    const window = try ctx.allocator.alloc(u8, flate.max_window_len);
    defer ctx.allocator.free(window);

    var decompressor = flate.Decompress.init(reader, .zlib, window);
    const decompressed_bytes = try decompressor.reader.allocRemaining(ctx.allocator, .unlimited);

    return try obj.Object.initFromBytes(decompressed_bytes);
}
