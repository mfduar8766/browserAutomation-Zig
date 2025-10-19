const std = @import("std");
const Logger = @import("common").Logger;
const Driver = @import("driver").Driver;
const DriverTypes = @import("driver").DriverTypes;
const Types = @import("common").Types;
const FileManager = @import("common").FileManager;

//zig build run -DchromeDriverPort=42069 -DchromeDriverExecPath=chromeDriver/chromedriver-mac-x64/chromedriver

// const std = @import("std");

// const Foo = struct {
//     const Self = @This();

//     pub fn init(allocator: std.mem.Allocator) !*Self {
//         var foo = try allocator.create(Self); // Allocates on heap
//         return foo;
//     }
// };

// pub fn main() !void {
//     var gpa = std.heap.page_allocator;
//     var foo = try Foo.init(gpa); // Returns a pointer to Foo

//     gpa.destroy(foo); // Must free the allocated memory
// }

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // const T = Channels.Chan(u8);
    // var chan = T.init(allocator);
    // _ = try chan.recv();

    var fm = try FileManager.init(allocator, true);

    // var driver = try Driver.init(allocator, Types.ChromeDriverConfigOptions{
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
        fm.deinit();
        // allocator.free(el);
        // driver.deinit();
        // fileM.deInit();
        // defer chan.deInit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Main::main()::leaking memory exiting program...");
    }
}
