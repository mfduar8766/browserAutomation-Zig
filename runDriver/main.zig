const std = @import("std");
const print = std.debug.print;
const Utils = @import("./utils//utils.zig");

pub const ExecCmdResponse = struct {
    exitCode: i32 = 0,
    message: []const u8 = "",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory, exiting program...");
    }
    print("Main::main()::executing chromeDriver exe...\n", .{});

    // const fileName = "startChromeDriver.sh";
    // var fileExists = true;
    // const cwd = std.fs.cwd();
    // checkIfFileExists(cwd, fileName) catch |e| {
    //     print("Main::main()::error:", .{@errorName(e)});
    //     fileExists = false;
    // };
    // if (fileExists) {
    //     try cwd.deleteFile(fileName);
    // }

    const argv = [_][]const u8{
        "chmod",
        "+x",
        "./startChromeDriver.sh",
    };
    var code = try Utils.executeCmds(3, allocator, &argv);
    try Utils.checkCode(code.exitCode, "Utils::checkCode()::cannot open chromeDriver, exiting program...");

    const arg2 = [_][]const u8{
        "./startChromeDriver.sh",
    };
    code = try Utils.executeCmds(1, allocator, &arg2);
    try Utils.checkCode(code.exitCode, "Utils::checkCode()::cannot open chromeDriver, exiting program...");
}
