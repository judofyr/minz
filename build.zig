const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("line-compressor", "src/zig/line-compressor.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    var main_tests = b.addTest("src/zig/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
