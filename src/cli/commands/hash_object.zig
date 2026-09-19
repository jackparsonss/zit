const std = @import("std");
const flate = std.compress.flate;

const constants = @import("common").constants;
const logger = @import("common").logger;
const obj = @import("common").objects;
const path = @import("common").path;

const Context = @import("../context.zig");

const ParsedArgs = struct {
    file_path: []const u8,
    w_flag: bool = false,
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
        if (std.mem.eql(u8, arg, "-w")) {
            parsed_args.w_flag = true;
        }
    }

    const blob = try obj.Blob.init(ctx.allocator, ctx.io, parsed_args.file_path);
    const object = obj.Object{ .blob = blob };

    const id = try object.get_id(ctx.allocator);
    defer id.deinit(ctx.allocator);

    const hash = try id.format(ctx.allocator);
    defer ctx.allocator.free(hash);

    if (parsed_args.w_flag) {
        try writeObject(ctx, hash, object);
    }

    try logger.log(ctx.io, "{s}\n", .{hash});
}

pub fn writeObject(ctx: Context, hash: []const u8, object: obj.Object) !void {
    const base = hash[0..2];
    const base_path = try std.mem.concat(ctx.allocator, u8, &.{ constants.OBJECTS_DIR, "/", base });
    defer ctx.allocator.free(base_path);
    const obj_path = hash[2..];

    const root_dir = try path.findRootDir(ctx.io);
    defer root_dir.close(ctx.io);

    const base_dir = root_dir.openDir(ctx.io, base_path, .{}) catch |err| blk: {
        if (err != error.FileNotFound) {
            return err;
        }

        try root_dir.createDirPath(ctx.io, base_path);
        break :blk try root_dir.openDir(ctx.io, base_path, .{});
    };
    defer base_dir.close(ctx.io);

    if (base_dir.openFile(ctx.io, obj_path, .{})) |existing| {
        // return early if file already exists
        existing.close(ctx.io);
        return;
    } else |err| {
        if (err != error.FileNotFound) {
            return err;
        }
    }

    var file = try base_dir.createFileAtomic(ctx.io, obj_path, .{});
    defer file.deinit(ctx.io);

    var file_buf: [4096]u8 = undefined;
    var file_writer = file.file.writer(ctx.io, &file_buf);
    const writer = &file_writer.interface;

    const window = try ctx.allocator.alloc(u8, flate.max_window_len);
    defer ctx.allocator.free(window);

    var z = try flate.Compress.init(writer, window, .zlib, .fastest);

    const header = try object.get_header(ctx.allocator);
    defer ctx.allocator.free(header);

    try z.writer.writeAll(header);
    try z.finish();
    try writer.flush();

    try file.link(ctx.io);
}
