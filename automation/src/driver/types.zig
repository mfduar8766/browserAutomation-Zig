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

pub const RequestUrlPaths = enum {
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
    SET_WINDOW_RECT,
    KEY_IN_VALUE,
    PRESS_ENTER,
};

/// ChromeDriver response ito /sessions API request
pub const ChromeDriverSessionResponse = struct {
    value: struct {
        capabilities: ?Capabilities = null,
        sessionId: ?[]const u8 = null,
        @"error": ?[]const u8 = null,
        message: ?[]const u8 = null,
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

pub const SetWindowHeightAndWidth = struct {
    width: i32,
    height: i32,
};

pub const KeyInValuePayload = struct {
    text: []const u8,
    value: ?[][]const u8 = null,
};

///KeyIn
///
///{
///"type": "key",
///"id": "keyboard",
///"actions": [
///{ "type": "keyDown", "value": "a" },  // Press 'a'
///{ "type": "keyUp", "value": "a" }     // Release 'a'
///]
///}
///
/// Pointer
///
/// {
///"type": "pointer",
///"id": "mouse",
///"parameters": { "pointerType": "mouse" },
///"actions": [
///{ "type": "pointerMove", "x": 100, "y": 200 },
///{ "type": "pointerDown", "button": 0 },  // Left-click
///{ "type": "pointerUp", "button": 0 }
///]
///}
///
/// Mouse Wheel
///
/// {
///"type": "wheel",
///"id": "scroll",
///"actions": [
///{ "type": "scroll", "deltaX": 0, "deltaY": 100 }
///]
///}
pub const WebDriverActions = struct {
    actions: []ActionParams,
};

pub const ActionParams = struct {
    type: []u8,
    id: []u8,
    actions: []Actions,
};

pub const Actions = struct {
    type: []u8,
    value: []u8,
};
