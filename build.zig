const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{
        .name = "line-compressor",
        .root_source_file = .{ .path = "src/zig/line-compressor.zig" },
        .optimize = optimize,
        .target = target,
    });
    b.default_step.dependOn(&exe.step);

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/zig/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const tests_run_step = b.addRunArtifact(tests);
    tests_run_step.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&tests_run_step.step);
}
