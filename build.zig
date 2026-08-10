const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // .strip = optimize != .Debug,
        .single_threaded = true,
    });

    const exe = b.addExecutable(.{
        .name = "a",
        .root_module = exe_mod,
    });
    b.getInstallStep().dependOn(&b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .prefix },
    }).step);

    const exe_check = b.addExecutable(.{
        .name = "check",
        .root_module = exe_mod,
    });

    const check = b.step("check", "Check if code compiles");
    check.dependOn(&exe_check.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
