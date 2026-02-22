const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zsx", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = false,
        .link_libcpp = false,
    });

    const exe = b.addExecutable(.{
        .name = "zsx",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "neko-client", .module = mod },
            },
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    b.installArtifact(exe);

    // const install_resources = b.addInstallDirectory(.{
    //     .source_dir = b.path("res"),
    //     .install_dir = .bin,
    //     .install_subdir = "res",
    // });
    // b.getInstallStep().dependOn(&install_resources.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);

    run_cmd.setCwd(.{ .cwd_relative = b.getInstallPath(.bin, "") });

    run_cmd.step.dependOn(b.getInstallStep());
}
