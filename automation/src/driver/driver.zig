const std = @import("std");
const Http = @import("common").Http;
const builtIn = @import("builtin");
const Types = @import("common").Types;
const Utils = @import("common").Utils;
const DriverTypes = @import("./types.zig");
const process = std.process;
const FileManager = @import("common").FileManager;
const FileActions = @import("common").Actions;
const config = @import("config");

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
    comptime chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}",
    chromeDriverPort: i32 = 4200,
    allocator: Allocator,
    chromeDriverVersion: []const u8 = Types.ChromeDriverVersion.getDriverVersion(0),
    chromeDriverExecPath: []const u8 = "",
    sessionID: []const u8 = "",
    isDriverRunning: bool = false,
    fileManager: FileManager = undefined,
    height: i32 = 1500,
    width: i32 = 1500,
    windowPositionX: i32 = 0,
    windowPositionY: i32 = 0,
    isHeadlessMode: bool = false,

    pub fn init(allocator: Allocator, options: ?Types.ChromeDriverConfigOptions) !Self {
        var driver = Driver{
            .allocator = allocator,
        };
        driver.fileManager = FileManager.init(std.heap.page_allocator) catch |e| {
            std.debug.print("Driver::init()::received error: {s}\n", .{@errorCast(e)});
            @panic("Driver::init()::failed to init driver, exiting program...");
        };
        try driver.checkOptions(options);
        if (driver.chromeDriverExecPath.len == 0) {
            try driver.fileManager.downloadChromeDriverVersionInformation(CHROME_DRIVER_DOWNLOAD_URL);
        }
        try driver.fileManager.executeFiles(driver.fileManager.setShFileByOs(FileActions.startDriverDetached));
        return driver;
    }
    pub fn deInit(self: *Self) void {
        self.allocator.free(self.sessionID);
        self.fileManager.deInit();
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
    ///var driver = Driver.init(allocator, logger);
    ///
    ///try driver.launchWindow("http://google.com");
    pub fn launchWindow(self: *Self, url: []const u8) !void {
        if (url.len == 0) {
            @panic("Driver::launchWindow()::url is empty cannot navigate to page, exiting program...");
        }
        if (!self.isDriverRunning) {
            @panic("Driver::launchWindow()::driver is not running...");
        }
        self.handleLaunchWindow(url) catch |e| {
            self.fileManager.logger.fatal("Driver::launchWindow()::Caught error: {}\n", @errorName(e));
            @panic("Driver::launchWindow()::cannout open the browser");
        };
    }
    pub fn closeWindow(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, null);
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(RequestUrlPaths.CLOSE_WINDOW, bufLen, &urlBuf, null);
        const res = try req.delete(urlApi, .{ .server_header_buffer = serverHeaderBuf }, 12);
        self.isDriverRunning = false;
        self.allocator.free(serverHeaderBuf);
        self.allocator.free(res);
        req.deinit();
        try self.fileManager.executeShFiles(self.fileManager.files.deleteDriverDetachedSh);
    }
    ///deleteSession - Used to delete current session of chromeDriver and close window
    pub fn deleteSession(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, null);
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(RequestUrlPaths.DELETE_SESSION, bufLen, &urlBuf, null);
        const res = try req.delete(urlApi, .{ .server_header_buffer = serverHeaderBuf }, 14);
        self.isDriverRunning = false;
        defer {
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
        try self.fileManager.executeShFiles(self.fileManager.files.deleteDriverDetachedSh);
    }
    /// findElement - Used to find the element by selector.
    ///
    ///Caller needs to free the memory .
    ///
    /// Find by css, xpath, tagName, id.
    pub fn findElement(self: *Self, selectorType: DriverTypes.SelectorTypes, comptime selectorName: []const u8) ![]const u8 {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 125 });
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
            u8,
            createFindElementQuery(selectorType, selectorName),
            .{},
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.post(urlApi, options, body, null);
        const parsed = try std.json.parseFromSlice(FindElementBySelectorResponse, self.allocator, res, .{ .ignore_unknown_fields = true });
        defer {
            allocator.free(body);
            parsed.deinit();
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
        const bytes = try self.allocator.alloc(u8, parsed.value.value.@"element-6066-11e4-a52e-4f735466cecf".len);
        std.mem.copyForwards(u8, bytes, parsed.value.value.@"element-6066-11e4-a52e-4f735466cecf");
        return @as([]const u8, bytes);
    }
    pub fn click(self: *Self, elementID: []const u8) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1500 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.CLICK_ELEMENT,
            bufLen,
            &urlBuf,
            elementID,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.post(urlApi, options, "{}", null);
        defer {
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    ///getElementByText = Used to get the elementID based on text,
    ///
    ///Caller must free the memory,
    pub fn getElementText(self: *Self, elementID: []const u8) ![]const u8 {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1024 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.GET_ELEMENT_TEXT,
            bufLen,
            &urlBuf,
            elementID,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.get(urlApi, options, null);
        const parsed = try std.json.parseFromSlice(GetElementTextResponse, self.allocator, res, .{ .ignore_unknown_fields = true });
        defer {
            parsed.deinit();
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
        const bytes = try self.allocator.alloc(u8, parsed.value.value.len);
        std.mem.copyForwards(u8, bytes, parsed.value.value);
        return @as([]const u8, bytes);
    }
    pub fn screenShot(self: *Self, fileName: ?[]const u8) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 500000 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.SCREEN_SHOT,
            bufLen,
            &urlBuf,
            null,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.get(urlApi, options, null);
        const parsed = try std.json.parseFromSlice(ScreenShotResponse, self.allocator, res, .{ .ignore_unknown_fields = true });
        try self.fileManager.saveScreenShot(fileName, parsed.value.value);
        defer {
            parsed.deinit();
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
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
    /// Call before waitForDriver ();and launchWindow();
    pub fn setWindowPosition(self: *Self, x: i32, y: i32) !void {
        if (self.isDriverRunning) {
            @panic("Driver::setWindowPosition()::driver is running cannot set window position while running");
        }
        self.windowPositionX = x;
        self.windowPositionY = y;
    }
    pub fn waitForDriver(self: *Self, waitOptions: DriverTypes.WaitOptions) !void {
        try self.fileManager.log(Types.LogLevels.INFO, "Driver::waitForDriver()::sleeping for {d} seconds waiting for driver to start....", waitOptions.driverWaitTime);
        std.time.sleep(waitOptions.driverWaitTime);
        _ = try Utils.checkIfPortInUse(self.allocator, self.chromeDriverPort);
        const MAX_RETRIES = 3;
        var reTries: i32 = 0;
        while (!self.isDriverRunning) {
            if (MAX_RETRIES > waitOptions.maxRetries) {
                @panic("Driver::waitForDriver()::failed to start chromeDriver, exiting program...");
            }
            try self.fileManager.log(Types.LogLevels.INFO, "Driver::waitForDriver()::sending PING to chromeDriver...", null);
            const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
            var req = Http.init(self.allocator, null);
            const bufLen = 250;
            var urlBuf: [bufLen]u8 = undefined;
            const urlApi = try self.getRequestUrl(
                RequestUrlPaths.STATUS,
                bufLen,
                &urlBuf,
                null,
            );
            const res = try req.get(urlApi, .{ .server_header_buffer = serverHeaderBuf }, 243);
            const parsed = try std.json.parseFromSlice(ChromeDriverStatusResponse, self.allocator, res, .{ .ignore_unknown_fields = true });
            if (parsed.value.value.ready) {
                self.isDriverRunning = true;
                self.allocator.free(serverHeaderBuf);
                self.allocator.free(res);
                req.deinit();
                parsed.deinit();
                break;
            }
            reTries += 1;
            std.time.sleep(waitOptions.reTryTimer);
        }
        if (self.isDriverRunning) {
            try self.fileManager.writeToStdOut();
        }
    }
    ///keyInValue - Used to keyin values into a text box
    ///
    /// Only supports keyin for text
    pub fn keyInValue(self: *Self, elementID: []const u8, input: []const u8) !void {
        var list = std.ArrayList([]const u8).init(self.allocator);
        try list.append(input);
        const slice = try list.toOwnedSlice();
        const payload = KeyInValuePayload{ .text = input, .value = slice };
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 14 });
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
        const body = try Utils.stringify(allocator, u8, payload, .{});
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.post(urlApi, options, body, null);
        defer {
            allocator.free(body);
            self.allocator.free(slice);
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    pub fn sendEnterCmd(self: *Self) !void {
        const f =
            \\{"actions":[{"type":"key","id":"keyboard","actions":[{"type":"keyDown","value":"\uE007"}]}]}
        ;
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 2006 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.PRESS_ENTER,
            bufLen,
            &urlBuf,
            null,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.post(urlApi, options, f, null);
        defer {
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    pub fn goBack(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1341 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.GO_BACK,
            bufLen,
            &urlBuf,
            null,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.post(urlApi, options, "{}", null);
        defer {
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    pub fn goForward(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1341 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.GO_FORWARD,
            bufLen,
            &urlBuf,
            null,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.post(urlApi, options, "{}", null);
        defer {
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    pub fn stopDriver(self: *Self) !void {
        try self.fileManager.executeFiles(self.fileManager.setShFileByOs(FileActions.deleteDriverDetached));
    }
    fn setWindowSize(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 52 });
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
            u8,
            windowSize,
            .{},
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.post(urlApi, options, body, null);
        defer {
            allocator.free(body);
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    fn setPosition(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 54 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            RequestUrlPaths.SET_POSITION,
            bufLen,
            &urlBuf,
            null,
        );
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allocator = fba.allocator();
        const windowPosition = WindowPositionPayload{ .x = self.windowPositionX, .y = self.windowPositionY };
        const body = try Utils.stringify(
            allocator,
            u8,
            windowPosition,
            .{},
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.post(urlApi, options, body, null);
        defer {
            allocator.free(body);
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    fn getSessionID(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
        defer self.allocator.free(serverHeaderBuf);
        var req = Http.init(self.allocator, null);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(RequestUrlPaths.NEW_SESSION, bufLen, &urlBuf, null);
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var arrayList = std.ArrayList(u8).init(fba.allocator());
        defer arrayList.deinit();

        var chromeDriverCapabilities = Types.ChromeCapabilities{};
        if (self.isHeadlessMode) {
            const array = [3][]const u8{ "--headless", "--disable-gpu", "--disable-extensions" };
            chromeDriverCapabilities.capabilities.alwaysMatch.@"goog:chromeOptions".args = array;
        }
        try std.json.stringify(chromeDriverCapabilities, .{ .emit_null_optional_fields = false }, arrayList.writer());
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const body = try req.post(urlApi, options, arrayList.items, 2081);
        const parsed = try std.json.parseFromSlice(ChromeDriverSessionResponse, self.allocator, body, .{ .ignore_unknown_fields = true });
        if (parsed.value.value.@"error") |e| {
            try self.fileManager.log(Types.LogLevels.ERROR, "Driver::getSessionID()::", .{
                .err = e,
                .message = parsed.value.value.message,
            });
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
        try self.fileManager.log(Types.LogLevels.INFO, "Driver::navigateToSite()::navigating to", url);
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(RequestUrlPaths.NAVIGATE_TO, bufLen, &urlBuf, null);
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        defer self.allocator.free(serverHeaderBuf);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 14 });
        defer req.deinit();
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var arrayList = std.ArrayList(u8).init(fba.allocator());
        defer arrayList.deinit();
        try std.json.stringify(ChromeDriverNavigateRequestPayload{ .url = url }, .{}, arrayList.writer());
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const body = try req.post(urlApi, options, arrayList.items, null);
        defer self.allocator.free(body);
    }
    fn checkOptions(self: *Self, options: ?Types.ChromeDriverConfigOptions) !void {
        if (options) |op| {
            if (op.chromeDriverPort) |port| {
                const code = try self.checkIfPortInUse(port);
                if (code.exitCode == 0) {
                    var buf: [6]u8 = undefined;
                    const intToString = try std.fmt.bufPrint(&buf, "{d}", .{code.exitCode});
                    try self.fileManager.log(Types.LogLevels.ERROR, "Driver::checkOptions()::port is currently in use", @as(
                        []const u8,
                        intToString,
                    ));
                    @panic("Driver::checkoptins()::port is in use, exiting program...");
                }
                self.chromeDriverPort = port;
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
            try self.fileManager.createFiles(op);
        }
    }
    fn checkIfPortInUse(self: *Self, port: i32) !Utils.ExecCmdResponse {
        var buf: [6]u8 = undefined;
        const formattedPort = try std.fmt.bufPrint(&buf, ":{d}", .{port});
        const args = [_][]const u8{
            "lsof", "-i", formattedPort,
        };
        const response = try Utils.executeCmds(3, self.allocator, &args);
        return response;
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
            if (config.te2e) {
                self.setHeadlessMode();
                try self.getSessionID();
                try self.fileManager.startE2E(url);
            } else {
                try self.getSessionID();
                try self.navigateToSite(url);
            }
        }
    }
};
