const std = @import("std");
const Utils = @import("../utils/utils.zig");

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

pub const LogLevels = enum(u2) {
    INFO = 0,
    WARNING = 1,
    ERROR = 2,
    FATAL = 3,
    pub fn get(key: u2) []const u8 {
        return switch (key) {
            0 => "INFO",
            1 => "WARNING",
            2 => "ERROR",
            3 => "FATAL",
        };
    }
};

pub const PlatForms = enum(u4) {
    LINUX,
    MAC_ARM_64,
    MAC_X64,
    WIN_32,
    WIN_64,
    pub fn getOS(key: u4) []const u8 {
        return switch (key) {
            0 => "linux64",
            1 => "mac-arm64",
            2 => "mac-x64",
            3 => "win32",
            4 => "win64",
            else => "UNKNOWN",
        };
    }
};

pub const ChromeDriverFileName = enum(u8) {
    LINUX,
    MAC_ARM_64,
    MAC_X64,
    WIN_32,
    WIN_64,
    pub fn getFileName(key: u4) []const u8 {
        return switch (key) {
            0 => "chromedriver-linux64.zip",
            1 => "chromedriver-mac-arm64.zip",
            2 => "chromedriver-mac-x64.zip",
            3 => "chromedriver-win32.zip",
            4 => "chromedriver-win64.zip",
            else => "UNKNOWN",
        };
    }
};

// ChromeDriverVersion - version of driver to download Stable, Beta, Dev
pub const ChromeDriverVersion = enum(u4) {
    STABLE,
    BETA,
    DEV,
    pub fn getDriverVersion(key: u4) []const u8 {
        return switch (key) {
            0 => "Stable",
            1 => "Beta",
            2 => "Dev",
            else => "UNKNOWN",
        };
    }
};

pub const ChromeCapabilities = struct {
    const Self = @This();
    capabilities: Capabilities = Capabilities{},
};

pub const Capabilities = struct {
    acceptInsecureCerts: bool = true,
    alwaysMatch: AlwaysMatchOptions = AlwaysMatchOptions{},
};

pub const AlwaysMatchOptions = struct {
    browserName: []const u8 = "chrome",
    @"goog:chromeOptions": GoogleChromeOptiions = GoogleChromeOptiions{},
};

// TODO: Make this configurable
pub const GoogleChromeOptiions = struct {
    args: ?[3][]const u8 = null,
};

pub const ChromeDriverResponse = struct {
    timestamp: []u8,
    channels: Channels,
};

const Channels = struct {
    Stable: Stable,
    Beta: Beta,
    Dev: Dev,
    Canary: Canary,
};

const Stable = struct {
    channel: []u8,
    version: []u8,
    revision: []u8,
    downloads: Downloads,
};

const Beta = struct {
    channel: []u8,
    version: []u8,
    revision: []u8,
    downloads: Downloads,
};

const Dev = struct {
    channel: []u8,
    version: []u8,
    revision: []u8,
    downloads: Downloads,
};

const Canary = struct {
    channel: []u8,
    version: []u8,
    revision: []u8,
    downloads: Downloads,
};

const Downloads = struct {
    chrome: []Chrome,
    chromedriver: []Chromedriver,
    // chromeHeadlessShell: []ChromeHeadlessShell
};

const Chrome = struct {
    platform: []u8,
    url: []u8,
};

const Chromedriver = struct {
    platform: []u8,
    url: []u8,
};

const ChromeHeadlessShell = struct {
    platform: []u8,
    url: []u8,
};

pub const FileExtensions = enum(u8) { TXT, PNG, JPG, LOG };
