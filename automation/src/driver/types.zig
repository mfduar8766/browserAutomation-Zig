const std = @import("std");

/// ChromeDriverConfigOptions - Options for setting up chromeDriver
pub const ChromeDriverConfigOptions = struct {
    /// chromeDriverExecPath - Path to chromeDriver exe file
    chromeDriverExecPath: ?[]const u8 = undefined,
    /// chromeDriverPort - Port chromeDriver will run on
    chromeDriverPort: ?i32 = undefined,
    /// chromeDriverVersion - Version of chromeDriver to use default is Stable
    chromeDriverVersion: ?[]const u8 = "Stable",
    /// args - ChromeDriver args
    args: ?[][]const u8 = undefined,
    /// chromeDriverOutFilePath - StdOut file for chromeDriver logs when running driver
    chromeDriverOutFilePath: ?[]const u8 = undefined,
};

/// WaitOptions - ChromeDriver options for wait for driver to start
pub const WaitOptions = struct {
    /// maxRetries - Number of attempts to PING chromeDriver to see if its up and running
    maxRetries: comptime_int = 3,
    /// driverWaitTime - Time to wait for chromeDriver exe to start is 10 seconds
    driverWaitTime: comptime_int = 10_000_000_000,
    /// reTryTimer - Amount of time before re tries expire is 15 seconds
    reTryTimer: comptime_int = 15_000_000_000,
};

pub const SelectorTypes = enum {
    CSS_TAG,
    ID_TAG,
    ///X_PATH - Used to select elements by regex.
    ///
    /// Example:
    ///
    ///"//button[@id=\"submit\"]"
    ///
    ///"//div[@class=\"item\"]"
    X_PATH,
    TAG_NAME,
    pub fn getSelector(key: u9) []const u8 {
        return switch (key) {
            0 => "css selector",
            1 => "id",
            3 => "xpath",
            4 => "tag name",
            else => "NOT_SUPPORTED",
        };
    }
};
