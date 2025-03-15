const std = @import("std");
const Logger = @import("common").Logger;
const Driver = @import("driver").Driver;
const DriverTypes = @import("driver").DriverTypes;
const Utils = @import("common").Utils;

// var running: bool = true;
// fn interrupt(_: i32) callconv(.C) void {
//     running = false;
// }
//     var sa: std.posix.Sigaction = .{
//         .handler = .{ .handler = interrupt },
//         .mask = std.posix.empty_sigset,
//         .flags = std.posix.SA.RESTART,
//     };
//     try std.posix.sigaction(std.posix.SIG.INT, &sa, null);
//     while (running) {
//         try logger.info("Main::main()::running program waiting for kill signal...", null);
//     }

//zig build run -DchromeDriverPort=42069 -DchromeDriverExecPath=chromeDriver/chromedriver-mac-x64/chromedriver

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // const startUIFile: []const u8 = "startUI.sh";
    // const cwd = Utils.getCWD();
    // try Utils.deleteFileIfExists(cwd, startUIFile);
    // const fileData =
    //     \\#!/bin/bash
    //     \\echo "Change dir to UI and start node server..."
    //     \\cd "UI"
    //     \\node index.js
    // ;
    // const file = try cwd.createFile(startUIFile, .{ .truncate = true });
    // try file.chmod(777);
    // try file.writeAll(fileData);
    // defer file.close();
    // const argv = [3][]const u8{
    //     "chmod",
    //     "+x",
    //     "./startUI.sh",
    // };
    // var code = try Utils.executeCmds(3, allocator, &argv);
    // std.debug.print("RESPONSE1: {d} {s}\n", .{ code.exitCode, code.message });
    // try Utils.checkExitCode(code.exitCode, code.message);
    // const arg2 = [1][]const u8{
    //     "./startUI.sh",
    // };
    // code = try Utils.executeCmds(1, allocator, &arg2);
    // std.debug.print("RESPONSE2: {d} {s}\n", .{ code.exitCode, code.message });
    // try Utils.checkExitCode(code.exitCode, code.message);

    var logger = try Logger.init("Logs");
    try logger.info("Main::main()::running program...", null);
    var driver = try Driver.init(allocator, logger, DriverTypes.ChromeDriverConfigOptions{
        .chromeDriverExecPath = "/Users/matheusduarte/Desktop/browserAutomation-Zig/example/chromeDriver/chromedriver-mac-x64/chromedriver",
        .chromeDriverPort = 4200,
    });
    try driver.waitForDriver(DriverTypes.WaitOptions{});
    try driver.launchWindow("https://jsonplaceholder.typicode.com");
    try driver.screenShot("test.png");
    std.time.sleep(5_000_000_000);
    try driver.stopDriver();
    defer {
        driver.deInit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }
}
