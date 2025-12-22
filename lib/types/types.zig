const std = @import("std");
const Utils = @import("../utils/utils.zig");

/// DriverConfigOptions - Options for setting up chromeDriver
pub const DriverConfigOptions = struct {
    /// driverExePath - Path to chromeDriver exe file
    driverExePath: ?[]const u8 = null,
    /// driverPort - Port chromeDriver will run on
    driverPort: ?i32 = null,
    /// driverVersion - Version of chromeDriver to use default is Stable
    driverVersion: ?[]const u8 = "Stable",
    /// driverOutFilePath - StdOut file for driver logs when running driver
    driverOutFilePath: ?[]const u8 = null,
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

pub const FileExtensions = enum(u8) {
    TXT,
    PNG,
    JPG,
    LOG,
    SH,
    pub fn get(key: u8) []const u8 {
        return switch (key) {
            0 => "txt",
            1 => "png",
            2 => "jpg",
            3 => "log",
            4 => "sh",
            else => "",
        };
    }
};

pub const FireFoxReleaseInfoResponse = struct {
    url: []const u8,
    assets_url: []const u8,
    upload_url: []const u8,
    html_url: []const u8,
    id: u64,
    author: ?User,
    node_id: []const u8,
    tag_name: []const u8,
    target_commitish: []const u8,
    name: []const u8,
    draft: bool,
    immutable: bool,
    prerelease: bool,
    created_at: []const u8,
    updated_at: []const u8,
    published_at: []const u8,
    assets: []Asset,
    tarball_url: []const u8,
    zipball_url: []const u8,
    body: []const u8,
    reactions: ?Reactions,
};

const User = struct {
    login: []const u8,
    id: u64,
    node_id: []const u8,
    avatar_url: []const u8,
    gravatar_id: []const u8,
    url: []const u8,
    html_url: []const u8,
    followers_url: []const u8,
    following_url: []const u8,
    gists_url: []const u8,
    starred_url: []const u8,
    subscriptions_url: []const u8,
    organizations_url: []const u8,
    repos_url: []const u8,
    events_url: []const u8,
    received_events_url: []const u8,
    type: []const u8,
    user_view_type: []const u8,
    site_admin: bool,
};

const Asset = struct {
    url: []const u8,
    id: u64,
    node_id: []const u8,
    name: []const u8,
    label: ?[]const u8,
    uploader: User,
    content_type: []const u8,
    state: []const u8,
    size: u64,
    digest: ?[]const u8,
    download_count: u64,
    created_at: []const u8,
    updated_at: []const u8,
    browser_download_url: []const u8,
};

const Reactions = struct {
    url: []const u8,
    total_count: u64,
    @"+1": u64,
    @"-1": u64,
    laugh: u64,
    hooray: u64,
    confused: u64,
    heart: u64,
    rocket: u64,
    eyes: u64,
};
