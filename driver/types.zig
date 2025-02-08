const std = @import("std");
const Utils = @import("../lib/utils/utils.zig");

pub const Options = struct {
    chromeDriverExecPath: ?[]const u8 = undefined,
    chromeDriverPort: ?i32 = undefined,
    chromeDriverVersion: ?[]const u8 = undefined,
    args: ?[][]const u8 = undefined,
    chromeDriverOutFilePath: ?[]const u8 = undefined,
};

pub const SelectorTypes = enum(u8) {
    CSS_TAG,
    ID_TAG,
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

pub const RequestUrlPaths = enum(u8) {
    NEW_SESSION,
    DELETE_SESSION,
    STATUS,
    TIME_OUTS,
    SET_TIME_OUTS,
    NAVIGATE_TO,
    GET_WINDOW_HANDLE,
    CLOSE_WINDOW,
    NEW_WINDOW,
    FIND_ELEMENT_BY_SELECTOR,
    GET_ELEMENT_TEXT,
    CLICK_ELEMENT,
    SCREEN_SHOT,
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

pub const FindElementBySelectorResponse = struct {
    value: struct {
        @"element-6066-11e4-a52e-4f735466cecf": []const u8,
    },
};

pub const GetElementTextResponse = struct {
    //TODO: Will this always be a string??
    value: []const u8,
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

pub const FindElementBy = struct {
    using: []const u8 = "",
    value: []const u8 = "",
};

pub const ScreenShotResponse = struct {
    value: []const u8,
};
