const std = @import("std");
const Http = @import("common").Http;
const builtIn = @import("builtin");
const Types = @import("common").Types;
const Utils = @import("common").Utils;
const DriverTypes = @import("./types.zig");
const process = std.process;
const FileManager = @import("common").FileManager;
const FileActions = @import("common").Actions;
const Config = @import("config");
const AllocatingWriter = std.io.Writer.Allocating;

const RequestUrlPaths = enum {
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
    GO_BACK,
    GO_FORWARD,
    SET_POSITION,
};

/// ChromeDriver response ito /sessions API request
const ChromeDriverSessionResponse = struct {
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

const FindElementBySelectorResponse = struct {
    value: struct {
        @"element-6066-11e4-a52e-4f735466cecf": []const u8,
    },
};

const GetElementTextResponse = struct {
    //TODO: Will this always be a string??
    value: []const u8,
};

///ChromeDriverStatusResponse - response from chromeDriver /status API to determine if chrome is ready to receive requests
const ChromeDriverStatusResponse = struct {
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

const ChromeDriverNavigateRequestPayload = struct {
    url: []const u8 = "",
};

const FindElementByPayload = struct {
    using: []const u8 = "",
    value: []const u8 = "",
};

const ScreenShotResponse = struct {
    value: []const u8,
};

const SetWindowHeightAndWidthPayload = struct {
    width: i32,
    height: i32,
};

const KeyInValuePayload = struct {
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
const WebDriverActionsPayload = struct {
    actions: []ActionParams,
};

const ActionParams = struct {
    type: []u8,
    id: []u8,
    actions: []Actions,
};

const Actions = struct {
    type: []u8,
    value: []u8,
};

///WindowPosition - Sets the location of window on screen X, Y axis
const WindowPositionPayload = struct { x: i32, y: i32 };

pub const Driver = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;
    const CHROME_DRIVER_DOWNLOAD_URL: []const u8 = "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json";
    const GECKO_DRIVER_URL: []const u8 = "https://api.github.com/repos/mozilla/geckodriver/releases/latest";
    const applicationJSON: []const u8 = "application/json";
    comptime chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}",
    comptime EXAMPLE_URL: []const u8 = "http://127.0.0.1:3000",
    chromeDriverPort: i32 = 4200,
    allocator: Allocator,
    chromeDriverVersion: []const u8 = Types.ChromeDriverVersion.getDriverVersion(0),
    chromeDriverExecPath: []const u8 = "",
    sessionID: []const u8 = "",
    isDriverRunning: bool = false,
    fileManager: *FileManager = undefined,
    height: i32 = 1500,
    width: i32 = 1500,
    windowPositionX: i32 = 0,
    windowPositionY: i32 = 0,
    isHeadlessMode: bool = false,
    runExampleUI: bool = false,

    pub fn init(allocator: Allocator, runExampleUI: bool, options: ?Types.ChromeDriverConfigOptions) !*Self {
        const driverPrt = try allocator.create(Self);
        driverPrt.* = Self{
            .allocator = allocator,
            .runExampleUI = runExampleUI,
        };
        driverPrt.fileManager = FileManager.init(allocator, Config.te2e) catch |e| {
            std.debug.print("Driver::init()::received error: {s}\n", .{@errorName(e)});
            @panic("Driver::init()::failed to init driver, exiting program...");
        };
        try driverPrt.checkOptions(options);
        try driverPrt.fileManager.executeFiles(driverPrt.fileManager.setShFileByOs(FileActions.startDriverDetached), false);
        return driverPrt;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.sessionID);
        self.fileManager.deinit();
        self.allocator.destroy(self);
    }
    ///setHeadlessMode - Used to run without a browser.
    ///
    ///Call before waitForDriver() and launchWindow().
    pub fn setHeadlessMode(self: *Self) void {
        if (self.isDriverRunning) {
            @panic("Driver::setHeadlessMode()::cannot call this after driver is running. Exiting function...");
        }
        self.isHeadlessMode = true;
    }
    ///Used to open the browser and navigate to URL
    ///
    ///Example:
    ///
    ///var driver = Driver.init(allocator, false, options);
    ///
    ///If wanting to run the exampleUI for a quick test pass in an empty URL string
    /// The example UI will run on http://127..0.1:3000
    ///
    ///try driver.launchWindow("http://google.com");
    pub fn launchWindow(self: *Self, url: []const u8) !void {
        if (!self.runExampleUI and !self.isDriverRunning and !Config.te2e and url.len == 0) {
            @panic("Driver::launchWindow()::url is empty cannot navigate to page, exiting program...");
        }
        if (!self.runExampleUI and !self.isDriverRunning) {
            @panic("Driver::launchWindow()::driver is not running...");
        }
        self.handleLaunchWindow(url) catch |e| {
            std.debug.print("Driver::launchWindow()::Caught error: {s}\n", .{@errorName(e)});
            @panic("Driver::launchWindow()::cannout open the browser");
        };
    }
    pub fn closeWindow(self: *Self) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.CLOSE_WINDOW,
            bufLen,
            &urlBuf,
            null,
        );
        const headers = std.http.Client.Request.Headers{};
        const res = try req.makeRequest(
            urlApi,
            .DELETE,
            headers,
            null,
        );
        defer self.allocator.free(res);
        self.isDriverRunning = false;
        try self.fileManager.executeShFiles(self.fileManager.files.deleteDriverDetachedSh);
    }
    ///deleteSession - Used to delete current session of chromeDriver and close window
    pub fn deleteSession(self: *Self) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.DELETE_SESSION,
            bufLen,
            &urlBuf,
            null,
        );
        const headers = std.http.Client.Request.Headers{};
        const res = try req.makeRequest(
            urlApi,
            .DELETE,
            headers,
            null,
        );
        defer self.allocator.free(res);
        self.isDriverRunning = false;
        try self.fileManager.executeShFiles(self.fileManager.files.deleteDriverDetachedSh);
    }
    /// findElement - Used to find the element by selector.
    ///
    ///Caller needs to free the memory .
    ///
    /// Find by css, xpath, tagName, id.
    pub fn findElement(self: *Self, selectorType: DriverTypes.SelectorTypes, comptime selectorName: []const u8) ![]const u8 {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.FIND_ELEMENT_BY_SELECTOR,
            bufLen,
            &urlBuf,
            null,
        );
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();
        const body = try Utils.stringify(
            allocator,
            createFindElementQuery(selectorType, selectorName),
            .{},
        );
        defer allocator.free(body);
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            body,
        );
        defer self.allocator.free(res);
        const parsed = try std.json.parseFromSlice(FindElementBySelectorResponse, self.allocator, res, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();
        const bytes = try self.allocator.alloc(u8, parsed.value.value.@"element-6066-11e4-a52e-4f735466cecf".len);
        std.mem.copyForwards(u8, bytes, parsed.value.value.@"element-6066-11e4-a52e-4f735466cecf");
        return @as([]const u8, bytes);
    }
    pub fn click(self: *Self, elementID: []const u8) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.CLICK_ELEMENT,
            bufLen,
            &urlBuf,
            elementID,
        );
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            null,
            elementID,
        );
        defer self.allocator.free(res);
    }
    ///getElementByText = Used to get the elementID based on text,
    ///
    ///Caller must free the memory,
    pub fn getElementText(self: *Self, elementID: []const u8) ![]const u8 {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.GET_ELEMENT_TEXT,
            bufLen,
            &urlBuf,
            elementID,
        );
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .GET,
            headers,
            null,
            elementID,
        );
        defer self.allocator.free(res);
        const parsed = try std.json.parseFromSlice(GetElementTextResponse, self.allocator, res, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();
        const bytes = try self.allocator.alloc(u8, parsed.value.value.len);
        std.mem.copyForwards(u8, bytes, parsed.value.value);
        return @as([]const u8, bytes);
    }
    pub fn screenShot(self: *Self, fileName: ?[]const u8) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.SCREEN_SHOT,
            bufLen,
            &urlBuf,
            null,
        );
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .GET,
            headers,
            null,
        );
        defer self.allocator.free(res);
        const parsed = try std.json.parseFromSlice(ScreenShotResponse, self.allocator, res, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();
        try self.fileManager.saveScreenShot(fileName, parsed.value.value);
    }
    ///setWindowReact - Used to set the height and width of window.
    ///
    /// Call before waitForDriver and launchWindow
    pub fn setWindowRect(self: *Self, height: i32, width: i32) !void {
        if (self.isDriverRunning) {
            @panic("Driver::setWindowRect()::driver is running cannot set window size while running");
        }
        self.height = height;
        self.width = width;
    }
    ///setWidowPositin - Used to set the window positon on the screen
    ///
    ///Call before waitForDriver ();and launchWindow();
    pub fn setWindowPosition(self: *Self, x: i32, y: i32) !void {
        if (self.isDriverRunning) {
            @panic("Driver::setWindowPosition()::driver is running cannot set window position while running");
        }
        self.windowPositionX = x;
        self.windowPositionY = y;
    }
    pub fn waitForDriver(self: *Self, waitOptions: DriverTypes.WaitOptions) !void {
        try self.log(Types.LogLevels.INFO, "Driver::waitForDriver()::sleeping for {d} seconds waiting for driver to start....", waitOptions.driverWaitTime);
        Utils.sleep(waitOptions.driverWaitTime);
        const MAX_RETRIES = waitOptions.maxRetries;
        var reTries: i32 = 0;
        const headers = std.http.Client.Request.Headers{};
        while (!self.isDriverRunning) {
            if (MAX_RETRIES > waitOptions.maxRetries) {
                @panic("Driver::waitForDriver()::failed to start chromeDriver, exiting program...");
            }
            try self.log(Types.LogLevels.INFO, "Driver::waitForDriver()::sending PING to chromeDriver...", null);
            const res = try self.makeDriverRequests(
                RequestUrlPaths.STATUS,
                .GET,
                headers,
                null,
                null,
            );
            const parsed = try std.json.parseFromSlice(ChromeDriverStatusResponse, self.allocator, res, .{
                .ignore_unknown_fields = true,
            });
            if (parsed.value.value.ready) {
                self.isDriverRunning = true;
                self.allocator.free(res);
                parsed.deinit();
                break;
            }
            reTries += 1;
            Utils.sleep(waitOptions.reTryTimer);
        }
    }
    ///keyInValue - Used to keyin values into a text box
    ///
    /// Only supports keyin for text
    pub fn keyInValue(self: *Self, elementID: []const u8, input: []const u8) !void {
        var list = std.ArrayList([]const u8).empty;
        try list.append(self.allocator, input);
        const slice = try list.toOwnedSlice(self.allocator);
        defer self.allocator.free(slice);
        const payload = KeyInValuePayload{ .text = input, .value = slice };
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.KEY_IN_VALUE,
            bufLen,
            &urlBuf,
            elementID,
        );
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();
        const body = try Utils.stringify(allocator, payload, .{});
        defer allocator.free(body);
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            body,
            elementID,
        );
        defer self.allocator.free(res);
    }
    pub fn sendEnterCmd(self: *Self) !void {
        const body: []const u8 =
            \\{"actions":[{"type":"key","id":"keyboard","actions":[{"type":"keyDown","value":"\uE007"}]}]}
        ;
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.PRESS_ENTER,
            bufLen,
            &urlBuf,
            null,
        );
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            @constCast(body),
        );
        defer self.allocator.free(res);
    }
    pub fn goBack(self: *Self) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.GO_BACK,
            bufLen,
            &urlBuf,
            null,
        );
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            null,
        );
        defer self.allocator.free(res);
    }
    pub fn goForward(self: *Self) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.GO_FORWARD,
            bufLen,
            &urlBuf,
            null,
        );
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            null,
        );
        defer self.allocator.free(res);
    }
    pub fn stopDriver(self: *Self) !void {
        if (self.isDriverRunning) {
            try self.fileManager.executeFiles(self.fileManager.setShFileByOs(FileActions.deleteDriverDetached), false);
        }
        if (self.runExampleUI) {
            try self.fileManager.stopExampleUI();
        }
        if (Config.te2e) {
            try self.fileManager.stopE2E();
        }
    }
    fn setWindowSize(self: *Self) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.SET_WINDOW_RECT,
            bufLen,
            &urlBuf,
            null,
        );
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();
        const windowSize = SetWindowHeightAndWidthPayload{ .height = self.height, .width = self.width };
        const body = try Utils.stringify(
            allocator,
            windowSize,
            .{},
        );
        defer allocator.free(body);
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            body,
        );
        defer self.allocator.free(res);
    }
    fn setPosition(self: *Self) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.SET_POSITION,
            bufLen,
            &urlBuf,
            null,
        );
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();
        const windowPosition = WindowPositionPayload{ .x = self.windowPositionX, .y = self.windowPositionY };
        const body = try Utils.stringify(
            allocator,
            windowPosition,
            .{},
        );
        defer allocator.free(body);
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const res = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            body,
        );
        defer self.allocator.free(res);
    }
    fn getSessionID(self: *Self) !void {
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.NEW_SESSION,
            bufLen,
            &urlBuf,
            null,
        );
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var chromeDriverCapabilities = Types.ChromeCapabilities{};
        if (self.isHeadlessMode) {
            const array = [3][]const u8{ "--headless", "--disable-gpu", "--disable-extensions" };
            chromeDriverCapabilities.capabilities.alwaysMatch.@"goog:chromeOptions".args = array;
        }
        var out = std.io.Writer.Allocating.init(fba.allocator());
        const writter = &out.writer;
        defer out.deinit();
        try std.json.Stringify.value(
            chromeDriverCapabilities,
            .{ .emit_null_optional_fields = false },
            writter,
        );
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const body = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            out.written(),
        );
        const parsed = try std.json.parseFromSlice(ChromeDriverSessionResponse, self.allocator, body, .{
            .ignore_unknown_fields = true,
        });
        if (parsed.value.value.@"error") |e| {
            const err = .{
                .err = e,
                .message = parsed.value.value.message,
            };
            try self.log(Types.LogLevels.ERROR, "Driver::getSessionID()::{any}", .{err});
            try self.stopDriver();
            @panic(parsed.value.value.message.?);
        }
        defer parsed.deinit();
        defer self.allocator.free(body);
        const bytes = try self.allocator.alloc(u8, parsed.value.value.sessionId.?.len);
        std.mem.copyForwards(u8, bytes, parsed.value.value.sessionId.?);
        self.sessionID = @as([]const u8, bytes);
        try self.setWindowSize();
        if (self.windowPositionX > 0 or self.windowPositionY > 0) {
            try self.setPosition();
        }
    }
    fn navigateToSite(self: *Self, url: []const u8) !void {
        try self.log(Types.LogLevels.INFO, "Driver::navigateToSite()::navigating to: {s}", url);
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.NAVIGATE_TO,
            bufLen,
            &urlBuf,
            null,
        );
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var out = std.io.Writer.Allocating.init(fba.allocator());
        const writter = &out.writer;
        defer out.deinit();
        try std.json.Stringify.value(
            ChromeDriverNavigateRequestPayload{ .url = url },
            .{},
            writter,
        );
        const headers = std.http.Client.Request.Headers{ .content_type = .{ .override = applicationJSON } };
        const body = try req.makeRequest(
            urlApi,
            .POST,
            headers,
            out.written(),
        );
        defer self.allocator.free(body);
    }
    fn checkOptions(self: *Self, options: ?Types.ChromeDriverConfigOptions) !void {
        if (options == null) {
            @panic("Driver::checkOptions()::received null or undefined for options. Please pass in options object to prceed.");
        }
        if (options) |op| {
            if (op.chromeDriverPort) |port| {
                const code = try Utils.checkIfPortInUse(self.allocator, port);
                if (code.exitCode == 0) {
                    try self.log(Types.LogLevels.ERROR, "Driver::checkOptions()::port:{d} is currently in use.", port);
                    @panic("Driver::checkoptins()::port is in use, exiting program...");
                }
                self.chromeDriverPort = port;
            } else {
                const code = try Utils.checkIfPortInUse(self.allocator, self.chromeDriverPort, null);
                if (code.exitCode == 0) {
                    try self.log(Types.LogLevels.ERROR, "Driver::checkOptions()::port:{d} is currently in use.", self.chromeDriverPort);
                    @panic("Driver::checkoptins()::port is in use, exiting program...");
                }
            }
            if (op.chromeDriverVersion) |version| {
                const stable = Types.ChromeDriverVersion.getDriverVersion(0);
                const beta = Types.ChromeDriverVersion.getDriverVersion(1);
                const dev = Types.ChromeDriverVersion.getDriverVersion(2);
                const isCorrecrtVersion = (Utils.eql(u8, version, stable) or Utils.eql(u8, version, beta) or Utils.eql(u8, version, dev));
                if (!isCorrecrtVersion) {
                    @panic("Driver::checkOptions()::incorrect driver version specefied. Expected (Stable, Beta, Dev)");
                } else {
                    self.chromeDriverVersion = op.chromeDriverVersion.?;
                }
            }
            if (op.chromeDriverExecPath) |path| {
                if (path.len > 0) self.chromeDriverExecPath = path;
            }
            if (op.chromeDriverExecPath == null or op.chromeDriverExecPath.?.len == 0) {
                try self.log(Types.LogLevels.INFO, "Driver::init()::cannot find driver exe. Downloading latest version", null);
                const isFireFox = try Utils.checkIfPortInUse(self.allocator, null, "firefox");
                if (isFireFox.exitCode == 0) {
                    try self.fileManager.downloadDriverExecutable("firefox", GECKO_DRIVER_URL);
                } else {
                    try self.fileManager.downloadChromeDriverVersionInformation(CHROME_DRIVER_DOWNLOAD_URL);
                }
            }
            try self.fileManager.createFiles(op, self.chromeDriverPort);
        }
    }
    fn makeDriverRequests(
        self: *Self,
        requestURL: RequestUrlPaths,
        method: std.http.Method,
        headers: std.http.Client.Request.Headers,
        body: ?[]u8,
        elementID: ?[]const u8,
    ) ![]const u8 {
        const bufLen = 300;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            requestURL,
            bufLen,
            &urlBuf,
            elementID,
        );
        var req = try Http.init(self.allocator, self.fileManager.logger);
        defer req.deinit();
        return req.makeRequest(
            urlApi,
            method,
            headers,
            body,
        );
    }
    fn getRequestUrl(
        self: *Self,
        chromeRequests: RequestUrlPaths,
        bufLen: comptime_int,
        buf: *[bufLen]u8,
        elementID: ?[]const u8,
    ) ![]const u8 {
        if (chromeRequests == RequestUrlPaths.STATUS) {
            const chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}";
            return try Utils.formatString(bufLen, buf, chromeDriverRestURL, .{
                self.chromeDriverPort,
                "status",
            });
        }
        const chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}";
        return switch (chromeRequests) {
            RequestUrlPaths.NEW_SESSION => try Utils.formatString(bufLen, buf, chromeDriverRestURL, .{
                self.chromeDriverPort,
                "session",
            }),
            RequestUrlPaths.NAVIGATE_TO => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "url",
                });
            },
            RequestUrlPaths.STATUS => try Utils.formatString(bufLen, buf, chromeDriverRestURL, .{
                self.chromeDriverPort,
                "status",
            }),
            RequestUrlPaths.CLOSE_WINDOW => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "window",
                });
            },
            RequestUrlPaths.DELETE_SESSION => {
                const newPath = chromeDriverRestURL ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                });
            },
            RequestUrlPaths.FIND_ELEMENT_BY_SELECTOR => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "element",
                });
            },
            RequestUrlPaths.GET_ELEMENT_TEXT => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}/{s}/{s}";
                var id: []const u8 = "";
                if (elementID) |elID| {
                    id = elID;
                }
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "element",
                    id,
                    "text",
                });
            },
            RequestUrlPaths.CLICK_ELEMENT => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}/{s}/{s}";
                var id: []const u8 = "";
                if (elementID) |elID| {
                    id = elID;
                }
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "element",
                    id,
                    "click",
                });
            },
            RequestUrlPaths.SCREEN_SHOT => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "screenshot",
                });
            },
            RequestUrlPaths.SET_WINDOW_RECT => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "window",
                    "rect",
                });
            },
            RequestUrlPaths.KEY_IN_VALUE => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}/{s}/{s}";
                var id: []const u8 = "";
                if (elementID) |elID| {
                    id = elID;
                }
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "element",
                    id,
                    "value",
                });
            },
            RequestUrlPaths.PRESS_ENTER => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "actions",
                });
            },
            RequestUrlPaths.GO_BACK => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "back",
                });
            },
            RequestUrlPaths.GO_FORWARD => {
                const newPath = chromeDriverRestURL ++ "/{s}/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "forward",
                });
            },
            RequestUrlPaths.SET_POSITION => {
                const newPath = chromeDriverRestURL ++ "/{s}/window/rect";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                });
            },
            else => "",
        };
    }
    fn createFindElementQuery(selectorType: DriverTypes.SelectorTypes, comptime selectorName: []const u8) FindElementByPayload {
        var findElementQuery = FindElementByPayload{};
        switch (selectorType) {
            DriverTypes.SelectorTypes.CSS_TAG => {
                findElementQuery.using = DriverTypes.SelectorTypes.getSelector(0);
                const newStr = "." ++ selectorName;
                findElementQuery.value = newStr;
            },
            DriverTypes.SelectorTypes.ID_TAG => {
                findElementQuery.using = DriverTypes.SelectorTypes.getSelector(0);
                const newStr = "#" ++ selectorName;
                findElementQuery.value = newStr;
            },
            DriverTypes.SelectorTypes.X_PATH => {
                findElementQuery.using = DriverTypes.SelectorTypes.getSelector(2);
            },
            DriverTypes.SelectorTypes.TAG_NAME => {
                findElementQuery.using = DriverTypes.SelectorTypes.getSelector(3);
            },
        }
        return findElementQuery;
    }
    fn handleLaunchWindow(self: *Self, url: []const u8) !void {
        if (self.isDriverRunning) {
            if (self.runExampleUI) {
                try self.fileManager.runExampleUI();
                try self.getSessionID();
                try self.navigateToSite(self.EXAMPLE_URL);
            } else if (Config.te2e) {
                self.setHeadlessMode();
                try self.getSessionID();
                try self.fileManager.startE2E(url);
            } else {
                try self.getSessionID();
                try self.navigateToSite(url);
            }
        }
    }
    fn log(self: *Self, logType: Types.LogLevels, comptime message: []const u8, data: anytype) !void {
        try self.fileManager.log(logType, message, data);
    }
};
