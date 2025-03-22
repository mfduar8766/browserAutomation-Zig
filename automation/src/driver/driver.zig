const std = @import("std");
const Http = @import("common").Http;
const Logger = @import("common").Logger;
const builtIn = @import("builtin");
const Types = @import("common").Types;
const Utils = @import("common").Utils;
const DriverTypes = @import("./types.zig");
const process = std.process;
const FileManager = @import("common").FileManager;
const Actions = @import("common").Actions;

pub const Driver = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;
    const CHROME_DRIVER_DOWNLOAD_URL: []const u8 = "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json";
    comptime chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}",
    chromeDriverPort: i32 = 4200,
    allocator: Allocator,
    logger: Logger = undefined,
    chromeDriverVersion: []const u8 = Types.ChromeDriverVersion.getDriverVersion(0),
    chromeDriverExecPath: []const u8 = "",
    sessionID: []const u8 = "",
    isDriverRunning: bool = false,
    fileManager: FileManager = undefined,

    pub fn init(allocator: Allocator, logger: ?Logger, options: ?Types.ChromeDriverConfigOptions) !Self {
        var driver = Driver{
            .allocator = allocator,
        };
        if (logger) |log| {
            driver.logger = log;
        } else {
            driver.logger = try Logger.init("Logs");
        }
        driver.fileManager = FileManager.init(std.heap.page_allocator, driver.logger);
        try driver.checkOptions(options);
        if (driver.chromeDriverExecPath.len == 0) {
            try driver.fileManager.downloadChromeDriverVersionInformation(CHROME_DRIVER_DOWNLOAD_URL);
        }
        try driver.fileManager.executeFiles(driver.fileManager.setShFileByOs(Actions.startDriverDetached));
        return driver;
    }
    pub fn deInit(self: *Self) void {
        self.allocator.free(self.sessionID);
        self.fileManager.deInit();
        self.logger.closeDirAndFiles();
    }
    ///Used to open the browser and navigate to URL
    ///Example:
    ///var driver = Driver.init(allocator, logger);
    ///try driver.launchWindow("http://google.com");
    pub fn launchWindow(self: *Self, url: []const u8) !void {
        if (url.len == 0) {
            @panic("Driver::launchWindow()::url is empty cannot navigate to page, exiting program...");
        }
        if (!self.isDriverRunning) {
            @panic("Driver::launchWindow()::driver is not running...");
        }
        if (self.isDriverRunning) {
            try self.getSessionID();
            try self.navigateToSite(url);
        }
    }
    pub fn closeWindow(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, null);
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(DriverTypes.RequestUrlPaths.CLOSE_WINDOW, bufLen, &urlBuf, null);
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
        const urlApi = try self.getRequestUrl(DriverTypes.RequestUrlPaths.DELETE_SESSION, bufLen, &urlBuf, null);
        const res = try req.delete(urlApi, .{ .server_header_buffer = serverHeaderBuf }, 14);
        self.isDriverRunning = false;
        defer {
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
        try self.fileManager.executeShFiles(self.fileManager.files.deleteDriverDetachedSh);
    }
    /// TODO: findById not supported, eed to add support for this.
    /// findElement - Used to find the element by selector caller needs to free the memory of returned value
    /// Find by css, xpath, tagName
    pub fn findElement(self: *Self, selectorType: DriverTypes.SelectorTypes, comptime selectorName: []const u8) ![]const u8 {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1024 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            DriverTypes.RequestUrlPaths.FIND_ELEMENT_BY_SELECTOR,
            bufLen,
            &urlBuf,
            null,
        );
        var buf: [1024]u8 = undefined;
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
        const parsed = try std.json.parseFromSlice(DriverTypes.FindElementBySelectorResponse, self.allocator, res, .{ .ignore_unknown_fields = true });
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
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1024 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            DriverTypes.RequestUrlPaths.CLICK_ELEMENT,
            bufLen,
            &urlBuf,
            elementID,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.get(urlApi, options, null);
        const parsed = try std.json.parseFromSlice(DriverTypes.GetElementTextResponse, self.allocator, res, .{ .ignore_unknown_fields = true });
        defer {
            parsed.deinit();
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    pub fn getElementText(self: *Self, elementID: []const u8) ![]const u8 {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1024 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            DriverTypes.RequestUrlPaths.GET_ELEMENT_TEXT,
            bufLen,
            &urlBuf,
            elementID,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.get(urlApi, options, null);
        const parsed = try std.json.parseFromSlice(DriverTypes.GetElementTextResponse, self.allocator, res, .{ .ignore_unknown_fields = true });
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
        var req = Http.init(self.allocator, .{ .maxReaderSize = 347828 });
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(
            DriverTypes.RequestUrlPaths.SCREEN_SHOT,
            bufLen,
            &urlBuf,
            null,
        );
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const res = try req.get(urlApi, options, null);
        const parsed = try std.json.parseFromSlice(DriverTypes.ScreenShotResponse, self.allocator, res, .{ .ignore_unknown_fields = true });
        try self.fileManager.saveScreenShot(fileName, parsed.value.value);
        defer {
            parsed.deinit();
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(res);
            req.deinit();
        }
    }
    pub fn stopDriver(self: *Self) !void {
        try self.fileManager.executeFiles(self.fileManager.setShFileByOs(Actions.deleteDriverDetached));
    }
    fn getSessionID(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
        defer self.allocator.free(serverHeaderBuf);
        var req = Http.init(self.allocator, null);
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(DriverTypes.RequestUrlPaths.NEW_SESSION, bufLen, &urlBuf, null);
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var arrayList = std.ArrayList(u8).init(fba.allocator());
        defer arrayList.deinit();
        try std.json.stringify(Types.ChromeCapabilities{ .capabilities = .{ .acceptInsecureCerts = true } }, .{}, arrayList.writer());
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const body = try req.post(urlApi, options, arrayList.items, 2081);
        const parsed = try std.json.parseFromSlice(DriverTypes.ChromeDriverSessionResponse, self.allocator, body, .{ .ignore_unknown_fields = true });
        if (parsed.value.value.@"error") |e| {
            try self.logger.err("Driver::getSessionID()::", .{
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
    }
    fn navigateToSite(self: *Self, url: []const u8) !void {
        try self.logger.info("Driver::navigateToSite()::navigating to", url);
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(DriverTypes.RequestUrlPaths.NAVIGATE_TO, bufLen, &urlBuf, null);
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
        defer self.allocator.free(serverHeaderBuf);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 14 });
        defer req.deinit();
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var arrayList = std.ArrayList(u8).init(fba.allocator());
        defer arrayList.deinit();
        try std.json.stringify(DriverTypes.ChromeDriverNavigateRequestPayload{ .url = url }, .{}, arrayList.writer());
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
                    try self.logger.err("Driver::checkOptions()::port is currently in use", intToString);
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
    pub fn waitForDriver(self: *Self, waitOptions: DriverTypes.WaitOptions) !void {
        try self.logger.info("Driver::waitForDriver()::sleeping for {d} seconds waiting for driver to start....", waitOptions.driverWaitTime);
        std.time.sleep(waitOptions.driverWaitTime);
        _ = try Utils.checkIfPortInUse(self.allocator, self.chromeDriverPort);
        const MAX_RETRIES = 3;
        var reTries: i32 = 0;
        while (!self.isDriverRunning) {
            if (MAX_RETRIES > waitOptions.maxRetries) {
                @panic("Driver::waitForDriver()::failed to start chromeDriver, exiting program...");
            }
            try self.logger.info("Driver::waitForDriver()::sending PING to chromeDriver...", null);
            const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
            var req = Http.init(self.allocator, null);
            const bufLen = 250;
            var urlBuf: [bufLen]u8 = undefined;
            const urlApi = try self.getRequestUrl(DriverTypes.RequestUrlPaths.STATUS, bufLen, &urlBuf, null);
            const res = try req.get(urlApi, .{ .server_header_buffer = serverHeaderBuf }, 245);
            const parsed = try std.json.parseFromSlice(DriverTypes.ChromeDriverStatus, self.allocator, res, .{ .ignore_unknown_fields = true });
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
    fn getRequestUrl(
        self: *Self,
        chromeRequests: DriverTypes.RequestUrlPaths,
        bufLen: comptime_int,
        buf: *[bufLen]u8,
        elementID: ?[]const u8,
    ) ![]const u8 {
        if (chromeRequests == DriverTypes.RequestUrlPaths.STATUS) {
            const chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}";
            return try Utils.formatString(bufLen, buf, chromeDriverRestURL, .{
                self.chromeDriverPort,
                "status",
            });
        }
        const chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}";
        return switch (chromeRequests) {
            DriverTypes.RequestUrlPaths.NEW_SESSION => try Utils.formatString(bufLen, buf, chromeDriverRestURL, .{
                self.chromeDriverPort,
                "session",
            }),
            DriverTypes.RequestUrlPaths.NAVIGATE_TO => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "url",
                });
            },
            DriverTypes.RequestUrlPaths.STATUS => try Utils.formatString(bufLen, buf, chromeDriverRestURL, .{
                self.chromeDriverPort,
                "status",
            }),
            DriverTypes.RequestUrlPaths.CLOSE_WINDOW => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "window",
                });
            },
            DriverTypes.RequestUrlPaths.DELETE_SESSION => {
                const newPath = chromeDriverRestURL ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                });
            },
            DriverTypes.RequestUrlPaths.FIND_ELEMENT_BY_SELECTOR => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "element",
                });
            },
            DriverTypes.RequestUrlPaths.GET_ELEMENT_TEXT => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}" ++ "/{s}" ++ "/{s}";
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
            DriverTypes.RequestUrlPaths.CLICK_ELEMENT => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}" ++ "/{s}" ++ "/{s}";
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
            DriverTypes.RequestUrlPaths.SCREEN_SHOT => {
                const newPath = chromeDriverRestURL ++ "/{s}" ++ "/{s}";
                return try Utils.formatString(bufLen, buf, newPath, .{
                    self.chromeDriverPort,
                    "session",
                    self.sessionID,
                    "screenshot",
                });
            },
            else => "",
        };
    }
    fn createFindElementQuery(selectorType: DriverTypes.SelectorTypes, comptime selectorName: []const u8) DriverTypes.FindElementBy {
        var findElementQuery = DriverTypes.FindElementBy{};
        switch (selectorType) {
            DriverTypes.SelectorTypes.CSS_TAG => {
                findElementQuery.using = DriverTypes.SelectorTypes.getSelector(0);
                const newStr = "." ++ selectorName;
                findElementQuery.value = newStr;
            },
            // TODO: Figure this out
            DriverTypes.SelectorTypes.ID_TAG => {
                findElementQuery.using = DriverTypes.SelectorTypes.getSelector(1);
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
};
