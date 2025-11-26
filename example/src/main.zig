const std = @import("std");
const Logger = @import("common").Logger;
const Driver = @import("driver").Driver;
const DriverTypes = @import("driver").DriverTypes;
const Types = @import("common").Types;
const FileManager = @import("common").FileManager;
const Utils = @import("common").Utils;
//zig build run -DchromeDriverPort=42069 -DchromeDriverExecPath=chromeDriver/chromedriver-mac-x64/chromedriver
const Config = @import("config");
const Gs = @import("driver").GracefulShutDown();

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const myStruct = struct {
        pub fn call(prt: *Driver) !void {
            // try prt.runExampleUI();
            // try prt.runSelectedTest("sampleTestThree_I.feature");
            try prt.waitForDriver(DriverTypes.WaitOptions{});
            try prt.launchWindow("");
        }
    };
    var driver = try Driver.init(allocator, Config.te2e, Types.ChromeDriverConfigOptions{
        .chromeDriverExecPath = "/Users/matheusduarte/Desktop/browserAutomation-Zig/example/chromeDriver/chromedriver-mac-x64/chromedriver",
        .chromeDriverPort = 4200,
    });
    Gs.init();
    try Gs.spawn(myStruct.call, .{driver});
    Gs.wait();
    try driver.stopDriver();

    // var gs = Utils.GracefulShutDown().init();
    // const fm = try FileManager.init(allocator, true);
    // try gs.spawn(myStruct.call, .{fm});
    // gs.wait();
    // try fm.stopExampleUI();
    // var driver = try Driver.init(allocator, true, Types.ChromeDriverConfigOptions{
    //     .chromeDriverExecPath = "/Users/matheusduarte/Desktop/browserAutomation-Zig/example/chromeDriver/chromedriver-mac-x64/chromedriver",
    //     .chromeDriverPort = 4200,
    // });
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
        // fm.deinit();
        // allocator.free(el);
        driver.deinit();
        // fileM.deInit();
        // defer chan.deInit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }
}
