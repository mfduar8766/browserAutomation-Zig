const std = @import("std");
const Logger = @import("common").Logger;
const Driver = @import("driver").Driver;
const DriverTypes = @import("driver").DriverTypes;
const Types = @import("common").Types;
const FileManager = @import("common").FileManager;
const Utils = @import("common").Utils;
//zig build run -DchromeDriverPort=42069 -DchromeDriverExecPath=chromeDriver/chromedriver-mac-x64/chromedriver
const Config = @import("config");
var Gs = @import("driver").GracefulShutDown().init();

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    const myStruct = struct {
        pub fn call(prt: *Driver) !void {
            try prt.launchWindow("");
        }
    };
    var driver = try Driver.init(allocator, true, Types.ChromeDriverConfigOptions{
        .chromeDriverExecPath = "",
        .chromeDriverPort = 42069,
    });
    try driver.waitForDriver(DriverTypes.WaitOptions{});
    try Gs.spawn(myStruct.call, .{driver});
    Gs.wait();
    try driver.stopDriver();

    // try driver.waitForDriver(DriverTypes.WaitOptions{});
    // try driver.launchWindow("http://127.0.0.1:3000/");
    // const el = try driver.findElement(DriverTypes.SelectorTypes.ID_TAG, "APjFqb");
    // try driver.keyInValue(el, "foo");
    // try driver.sendEnterCmd();
    // std.time.sleep(5_000_000_000);
    // try driver.goBack();
    // std.time.sleep(5_000_000_000);
    // try driver.goForward();
    // std.time.sleep(5_000_000_000);
    // try driver.stopDriver();
    defer {
        // logger.deinit();
        // allocator.free(el);
        driver.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }
}
