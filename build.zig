const std = @import("std");

const DAYS = 24;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const util_mod = b.addModule("util", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("util/root.zig"),
    });

    //comptime var days: [DAYS][]const u8 = undefined;
    var days_exe: [DAYS]*std.Build.Step.Compile = undefined;
    inline for (0..DAYS) |day| {
        const day_str = std.fmt.comptimePrint("{d:02}", .{day + 1});
        const day_full = "day" ++ day_str;
        const day_file = day_str ++ "/main.zig";

        days_exe[day] = b.addExecutable(.{
            .name = day_full,
            .root_source_file = b.path(day_file),
            .target = target,
            .optimize = optimize,
        });
        days_exe[day].root_module.addImport("util", util_mod);
        b.installArtifact(days_exe[day]);

        const run_cmd = b.addRunArtifact(days_exe[day]);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(day_full, "Run day " ++ day_str);
        run_step.dependOn(&run_cmd.step);

        // Tests
        const day_unit_tests = b.addTest(.{
            .root_source_file = b.path(day_file),
            .target = target,
            .optimize = optimize,
        });
        const run_day_unit_tests = b.addRunArtifact(day_unit_tests);
        const test_step = b.step("test_" ++ day_full, "Run unit tests for day" ++ day_str);
        test_step.dependOn(&run_day_unit_tests.step);
    }
}
