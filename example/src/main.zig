const std = @import("std");
const Logger = @import("common").Logger;
const Driver = @import("driver").Driver;
const DriverTypes = @import("driver").DriverTypes;
const Types = @import("common").Types;

//zig build run -DchromeDriverPort=42069 -DchromeDriverExecPath=chromeDriver/chromedriver-mac-x64/chromedriver

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var logger = try Logger.init("Logs");
    try logger.info("Main::main()::running program...", null);

    // const T = Channels.Chan(u8);
    // var chan = T.init(allocator);
    // _ = try chan.recv();

    var driver = try Driver.init(allocator, logger, Types.ChromeDriverConfigOptions{
        .chromeDriverExecPath = "/Users/matheusduarte/Desktop/browserAutomation-Zig/example/chromeDriver/chromedriver-mac-x64/chromedriver",
        .chromeDriverPort = 4200,
    });
    try driver.waitForDriver(DriverTypes.WaitOptions{});
    try driver.launchWindow("https://www.google.com/");
    const el = try driver.findElement(DriverTypes.SelectorTypes.ID_TAG, "APjFqb");
    try driver.keyInValue(el, "foo");
    try driver.sendEnterCmd();
    std.time.sleep(5_000_000_000);
    try driver.goBack();
    std.time.sleep(5_000_000_000);
    try driver.goForward();
    std.time.sleep(5_000_000_000);
    try driver.stopDriver();
    defer {
        allocator.free(el);
        // defer chan.deInit();
        driver.deInit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }
}
