const std = @import("std");
const print = std.debug.print;
const Logger = @import("lib/logger/logger.zig").Logger;
const Utils = @import("lib/utils/utils.zig");
const Driver = @import("./driver/driver.zig").Driver;
const DriverOptions = @import("./driver/types.zig").Options;

// https://stackoverflow.com/questions/72122366/how-to-initialize-variadic-function-arguments-in-zig
// https://www.reddit.com/r/Zig/comments/y5b2xw/anytype_vs_comptime_t/
// https://ziggit.dev/t/format-timestamp-into-iso-8601-strings/3824
// https://www.reddit.com/r/Zig/comments/l0ne7b/is_there_a_way_of_adding_an_optional_fields_in/
// https://ziggit.dev/t/how-to-set-struct-field-with-runtime-values/2758/6
// https://www.aolium.com/karlseguin/cf03dee6-90e1-85ac-8442-cf9e6c11602a
// https://cookbook.ziglang.cc/08-02-external.html STD.IO
// BETTER CHROME URL STABLE VERSIONS https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json
// https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json
// STABLE BETA ECT https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json
// CHROME-DRIVER-YOUTUBE: https://www.youtube.com/watch?v=F2jMzBW1Vl4&ab_channel=RakibulYeasin
// https://joeymckenzie.tech/blog/ziggin-around-with-linked-lists
// https://w3c.github.io/webdriver/#endpoints
// https://www.cyberciti.biz/faq/unix-linux-check-if-port-is-in-use-command/
// https://zig.news/mattnite/import-and-packages-23mb
// https://ziggit.dev/t/how-to-import-a-module-inside-my-module-so-user-dont-need-to-import-it-again/5213
// https://ziggit.dev/t/how-to-import-a-module-inside-my-module-so-user-dont-need-to-import-it-again/5213/4

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var logger = try Logger.init("Logs");
    try logger.info("Main::main()::program running...", null);
    var driver = try Driver.init(allocator, logger, DriverOptions{ .chromeDriverExecPath = "/Users/matheusduarte/Desktop/LearnZig/chromeDriver/chromedriver-mac-x64/chromedriver", .chromeDriverPort = 42069, .chromeDriverVersion = "Stable" });
    try driver.launchWindow("https://jsonplaceholder.typicode.com/");
    defer {
        logger.closeDirAndFiles();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }

    // const arg = [_][]const u8{
    //     "chmod",
    //     "+x",
    //     "./runDriver.sh",
    // };
    // const code = try Utils.executeCmds(3, allocator, &arg);
    // try Utils.checkCode(code.exitCode, "Utils::checkCode()::cannot open chromeDriver, exiting program...");

    // const arg2 = [_][]const u8{
    //     "./runDriver.sh",
    // };
    // const code2 = try Utils.executeCmds(1, allocator, &arg2);
    // try Utils.checkCode(code2.exitCode, "Utils::checkCode()::cannot open chromeDriver, exiting program...");
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
