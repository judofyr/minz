const Build = @import("std").Build;

pub fn build(b: *Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{
        .name = "line-compressor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zig/line-compressor.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });
    b.installArtifact(exe);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zig/main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });
    const tests_run_step = b.addRunArtifact(tests);
    tests_run_step.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&tests_run_step.step);
}
