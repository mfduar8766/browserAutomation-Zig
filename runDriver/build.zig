const std = @import("std");
// const CrossTarget = std.zig.CrossTarget;

// const LINUX_X86: CrossTarget = CrossTarget{
//     .cpu_arch = .x86,
//     .os_tag = .linux,
// };
// const LINUX_X86_64: CrossTarget = CrossTarget{
//     .cpu_arch = .x86_64,
//     .os_tag = .linux,
// };
// const LINUX_ARM: CrossTarget = CrossTarget{
//     .cpu_arch = .arm,
//     .os_tag = .linux,
// };
// const MAC_AARCH_64: CrossTarget = CrossTarget{
//     .cpu_arch = .aarch64,
//     .os_tag = .macos,
// };
// const MAC_X86_64: CrossTarget = CrossTarget{
//     .cpu_arch = .x86_64,
//     .os_tag = .macos,
// };
// const WIN_X86: CrossTarget = CrossTarget{
//     .cpu_arch = .x86,
//     .os_tag = .windows,
// };
// const WIN_X86_64: CrossTarget = CrossTarget{
//     .cpu_arch = .x86_64,
//     .os_tag = .windows,
// };
// const targets: [7]std.zig.CrossTarget = [7]std.zig.CrossTarget{
//     LINUX_X86,
//     LINUX_ARM,
//     LINUX_X86_64,
//     MAC_AARCH_64,
//     MAC_X86_64,
//     WIN_X86,
//     WIN_X86_64,
// };

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSafe,
    });
    const target = b.standardTargetOptions(.{});
    const options = b.addOptions();

    const chromeDriverPort = b.option([]const u8, "chromeDriverPort", "ChromeDriver port") orelse "42069";
    const chromeDriverExecPath = b.option([]const u8, "chromeDriverExecPath", "Path to chromeDriver executable") orelse "";
    options.addOption([]const u8, "chromeDriverPort", chromeDriverPort);
    options.addOption([]const u8, "chromeDriverExecPath", chromeDriverExecPath);

    const exe = b.addExecutable(.{
        .name = "runDriver",
        .root_source_file = b.path("main.zig"),
        .optimize = optimize,
        .target = target,
    });
    const mod = b.addModule("lib", .{
        .root_source_file = b.path("../lib/main.zig"),
    });
    b.installArtifact(exe);
    exe.root_module.addImport("lib", mod);
    exe.root_module.addOptions("config", options);

    const runCmd = b.addRunArtifact(exe);
    runCmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        runCmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&runCmd.step);

    // const lib_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    // for (targets) |target| {
    //     const libRoot = b.addStaticLibrary(.{
    //         .name = "root",
    //         .root_source_file = b.path("src/root.zig"),
    //         .target = b.resolveTargetQuery(target),
    //         .optimize = optimize,
    //     });
    //     const exe = b.addExecutable(.{
    //         .name = "automation",
    //         .root_source_file = b.path("src/main.zig"),
    //         .optimize = optimize,
    //         .target = b.resolveTargetQuery(target),
    //     });
    // //     const targetOutExe = b.addInstallArtifact(
    //         exe,
    //         .{
    //             .dest_dir = .{
    //                 .override = .{
    //                     .custom = try target.zigTriple(b.allocator),
    //                 },
    //             },
    //         },
    //     );
    //     const targetOutLibRoot = b.addInstallArtifact(
    //         libRoot,
    //         .{
    //             .dest_dir = .{
    //                 .override = .{
    //                     .custom = try target.zigTriple(b.allocator),
    //                 },
    //             },
    //         },
    //     );
    //     b.getInstallStep().dependOn(&targetOutExe.step);
    //     b.getInstallStep().dependOn(&targetOutLibRoot.step);
    // }
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
// pub fn build(b: *std.Build) void {
//     // Standard target options allows the person running `zig build` to choose
//     // what target to build for. Here we do not override the defaults, which
//     // means any target is allowed, and the default is native. Other options
//     // for restricting supported target set are available.
//     const target = b.standardTargetOptions(.{});

//     // Standard optimization options allow the person running `zig build` to select
//     // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
//     // set a preferred release mode, allowing the user to decide how to optimize.
//     const optimize = b.standardOptimizeOption(.{});

//     const lib = b.addStaticLibrary(.{
//         .name = "root",
//         // In this case the main source file is merely a path, however, in more
//         // complicated build scripts, this could be a generated file.
//         .root_source_file = b.path("src/root.zig"),
//         .target = target,
//         .optimize = optimize,
//     });

//     // This declares intent for the library to be installed into the standard
//     // location when the user invokes the "install" step (the default step when
//     // running `zig build`).
//     b.installArtifact(lib);

//     const exe = b.addExecutable(.{
//         .name = "automation",
//         .root_source_file = b.path("src/main.zig"),
//         .target = target,
//         .optimize = optimize,
//     });

//     // This declares intent for the executable to be installed into the
//     // standard location when the user invokes the "install" step (the default
//     // step when running `zig build`).
//     b.installArtifact(exe);

//     // This *creates* a Run step in the build graph, to be executed when another
//     // step is evaluated that depends on it. The next line below will establish
//     // such a dependency.
//     const run_cmd = b.addRunArtifact(exe);

//     // By making the run step depend on the install step, it will be run from the
//     // installation directory rather than directly from within the cache directory.
//     // This is not necessary, however, if the application depends on other installed
//     // files, this ensures they will be present and in the expected location.
//     run_cmd.step.dependOn(b.getInstallStep());

//     // This allows the user to pass arguments to the application in the build
//     // command itself, like this: `zig build run -- arg1 arg2 etc`
//     if (b.args) |args| {
//         run_cmd.addArgs(args);
//     }

//     // This creates a build step. It will be visible in the `zig build --help` menu,
//     // and can be selected like this: `zig build run`
//     // This will evaluate the `run` step rather than the default, which is "install".
//     const run_step = b.step("run", "Run the app");
//     run_step.dependOn(&run_cmd.step);

//     // Creates a step for unit testing. This only builds the test executable
//     // but does not run it.
//     const lib_unit_tests = b.addTest(.{
//         .root_source_file = b.path("src/root.zig"),
//         .target = target,
//         .optimize = optimize,
//     });

//     const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

//     const exe_unit_tests = b.addTest(.{
//         .root_source_file = b.path("src/main.zig"),
//         .target = target,
//         .optimize = optimize,
//     });

//     const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

//     // Similar to creating the run step earlier, this exposes a `test` step to
//     // the `zig build --help` menu, providing a way for the user to request
//     // running the unit tests.
//     const test_step = b.step("test", "Run unit tests");
//     test_step.dependOn(&run_lib_unit_tests.step);
//     test_step.dependOn(&run_exe_unit_tests.step);
// }
