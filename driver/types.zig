const std = @import("std");
const Utils = @import("../lib/utils/utils.zig");

pub const Options = struct {
    chromeDriverExecPath: ?[]const u8 = undefined,
    chromeDriverPort: ?i32 = undefined,
    chromeDriverVersion: ?[]const u8 = undefined,
    args: ?[][]const u8 = undefined,
    logFilePath: ?[]const u8 = undefined,
};

pub const RequestUrlPaths = enum(u8) {
    NEW_SESSION,
    DELETE_SESSION,
    STATUS,
    TIME_OUTS,
    SET_TIME_OUTS,
    NAVIGATE_TO,
    GET_CURR_URL,
    GET_WINDOW_HANDLE,
    CLOSE_WINDOW,
    NEW_WINDOW,
    FIND_ELEMENT,
    pub fn getUrlPath(bufLen: comptime_int, buf: *[bufLen]u8, key: u8, sessionID: []const u8, port: i32) ![]const u8 {
        const chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}";
        return switch (key) {
            0 => {
                return try Utils.formatString(bufLen, buf, chromeDriverRestURL, .{
                    port,
                    "session",
                });
            },
            1 => "http://localhost:4444/",
            2 => "",
            3 => "",
            4 => "",
            5 => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    port,
                    "session",
                    sessionID,
                    "url",
                });
            },
            6 => "",
            7 => "",
            8 => "",
            9 => "",
            else => "",
        };
    }
};
/// ChromeDriver response to /sessions API request
pub const ChromeDriverSessionResponse = struct {
    value: struct {
        capabilities: Capabilities,
        sessionId: []const u8,
    },
};

/// ChromeDriver response to /sessions API call
const Capabilities = struct {
    acceptInsecureCerts: bool,
    browserName: []const u8,
    browserVersion: []const u8,
    chrome: Chrome,
    @"fedcm:accounts": bool,
    @"goog:chromeOptions": GooglChromeOptions,
    networkConnectionEnabled: bool,
    pageLoadStrategy: []const u8,
    platformName: []const u8,
    proxy: Proxy,
    setWindowRect: bool,
    strictFileInteractability: bool,
    timeouts: Timeouts,
    unhandledPromptBehavior: []const u8,
    @"webauthn:extension:credBlob": bool,
    @"webauthn:extension:largeBlob": bool,
    @"webauthn:extension:minPinLength": bool,
    @"webauthn:extension:prf": bool,
    @"webauthn:virtualAuthenticators": bool,
};

/// ChromeDriver response to /sessions API call
const Chrome = struct {
    chromedriverVersion: []const u8,
    userDataDir: []const u8,
};

/// ChromeDriver response to /sessions API call
const GooglChromeOptions = struct {
    debuggerAddress: []const u8,
};

/// ChromeDriver response to /sessions API call
const Proxy = struct {
    // Add fields if needed for proxy
};

/// ChromeDriver response to /sessions API call
const Timeouts = struct {
    implicit: u32,
    pageLoad: u32,
    script: u32,
};

///ChromeDriverStatus - response from chromeDriver /status API to determine if chrome is ready to receive requests
pub const ChromeDriverStatus = struct {
    value: struct {
        build: struct {
            version: []const u8,
        },
        message: []const u8,
        os: struct {
            arch: []const u8,
            name: []const u8,
            version: []const u8,
        },
        ready: bool,
    },
};

pub const ChromeDriverNavigateRequestPayload = struct {
    url: []const u8 = "",
};
