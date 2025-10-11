const std = @import("std");
const FileManager = @import("common").FileManager;
const Utils = @import("common").Utils;

pub fn main() !void {
    // A standard general-purpose allocator is required.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const value = Utils.getEnvValueByKey(allocator, "TEST_SITE_URL") catch |e| {
        Utils.printLn("received error: {}", e);
        return e;
    };
    defer allocator.free(value);
    std.debug.print("PATH: {s}\n", .{value});

    var FM = try FileManager.init(allocator);
    defer FM.deInit();
    try FM.startE2E(value);
    Utils.printLn("Sleeping for 30 seconds...", .{});
    Utils.sleep(30000);
    try FM.stopE2E();
}

//TEST CODE
// pub fn Foo(allocator: std.mem.Allocator) !void {
//     const cwd = Utils.getCWD(); // returns fs.Dir
//     const CWD_PATH = try cwd.realpathAlloc(allocator, ".");
//     defer allocator.free(CWD_PATH);
//     std.debug.print("CWD: {s}\n", .{CWD_PATH});

//     try Utils.deleteFileIfExists(cwd, "foo.log");
//     var file = try cwd.createFile("foo.log", .{
//         .truncate = true,
//         .read = true,
//     }); // Added .read for cross-platform File requirement
//     defer file.close();

//     const script_path = "/Users/matheusduarte/Desktop/browserAutomation-Zig/e2e/buildAndInstall.sh";
//     const log_file = "foo.log";
//     const command_str = try std.fmt.allocPrint(allocator, "{s} > {s} 2>&1", .{ script_path, log_file });
//     defer allocator.free(command_str);
//     var child = std.process.Child.init(&[_][]const u8{ "/bin/bash", "-c", command_str }, allocator);
//     try child.spawn();
//     const term = try child.wait();
//     switch (term) {
//         .Exited => |code| {
//             std.debug.print("Process exited with code {}\n", .{code});
//         },
//         else => {
//             std.debug.print("Process did not exit normally: {}\n", .{term});
//         },
//     }
// }
