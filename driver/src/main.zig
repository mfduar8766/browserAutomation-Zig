const std = @import("std");
const Driver = @import("./driver.zig").Driver;
const DriverOptions = @import("./types.zig").DriverOptions;
const Logger = @import("lib").Logger;

pub fn main() !void {
    var logger = try Logger.init("MY_LOG");
    try logger.info("LOGGGG\n", null);
    defer logger.closeDirAndFiles();
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // var driver = try Driver.init(allocator, null, DriverOptions{ .chromeDriverExecPath = "/Users/matheusduarte/Desktop/LearnZig/chromeDriver/chromedriver-mac-x64/chromedriver", .chromeDriverPort = 42069, .chromeDriverVersion = "Stable" });
    // try driver.launchWindow("https://jsonplaceholder.typicode.com/");
    // defer {
    //     driver.deInit();
    //     const deinit_status = gpa.deinit();
    //     if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    // }
}
