const std = @import("std");
const manifest = @import("build.zig.zon");

const Package = struct {
    name: []const u8,
    module: *std.Build.Module,
};

fn addPackage(
    b: *std.Build,
    name: []const u8,
    root_source_file: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    common: *std.Build.Module,
) *std.Build.Module {
    const module = b.addModule(name, .{
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
    });
    module.addImport("common", common);
    return module;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", manifest.version);

    const common = b.addModule("common", .{
        .root_source_file = b.path("src/common/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cli = addPackage(
        b,
        "cli",
        b.path("src/cli/cli.zig"),
        target,
        optimize,
        common,
    );
    cli.addOptions("build_options", build_options);

    const packages = [_]Package{
        .{ .name = "common", .module = common },
        .{ .name = "cli", .module = cli },
    };

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    for (packages) |package| {
        exe_module.addImport(package.name, package.module);
    }

    const exe = b.addExecutable(.{
        .name = "zit",
        .root_module = exe_module,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run tests");
    inline for (packages) |package| {
        const package_tests = b.addTest(.{
            .root_module = package.module,
        });
        test_step.dependOn(&b.addRunArtifact(package_tests).step);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);
}
