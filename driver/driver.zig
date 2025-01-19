const std = @import("std");
const Http = @import("../lib/main.zig").Http;
const Logger = @import("../lib/main.zig").Logger;
const builtIn = @import("builtin");
const Types = @import("../lib/main.zig").Types;
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const Utils = @import("../lib/main.zig").Utils;
const DriverTypes = @import("./types.zig");
const process = std.process;
const FileManager = @import("../fileManager/fileManager.zig").FileManager;

// kill -9 PID
// p kill -9 chromedri

pub const Driver = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;
    const CHROME_DRIVER_DOWNLOAD_URL: []const u8 = "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json";
    comptime chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/{s}",
    chromeDriverPort: i32 = 42060,
    allocator: Allocator,
    logger: Logger = undefined,
    chromeDriverVersion: []const u8 = Types.ChromeDriverVersion.getDriverVersion(0),
    chromeDriverExecPath: []const u8 = "",
    sessionID: []const u8 = "",
    isDriverRunning: bool = false,
    fileManager: FileManager = undefined,

    pub fn init(allocator: Allocator, logger: ?Logger, options: ?DriverTypes.Options) !Self {
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
        try driver.fileManager.executeShFiles(driver.fileManager.shFiles.startDriverDetachedSh);
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
        try self.waitForDriver();
        if (self.isDriverRunning) {
            try self.getSessionID();
            try self.navigateToSite(url);
        }
    }
    fn getSessionID(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
        defer self.allocator.free(serverHeaderBuf);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1024 });
        defer req.deinit();
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(0, bufLen, &urlBuf);
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var arrayList = std.ArrayList(u8).init(fba.allocator());
        defer arrayList.deinit();
        try std.json.stringify(Types.ChromeCapabilities{ .capabilities = .{ .acceptInsecureCerts = true } }, .{}, arrayList.writer());
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const body = try req.post(urlApi, options, arrayList.items, 892);
        const parsed = try std.json.parseFromSlice(DriverTypes.ChromeDriverSessionResponse, self.allocator, body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();
        defer self.allocator.free(body);
        const bytes = try self.allocator.alloc(u8, parsed.value.value.sessionId.len);
        std.mem.copyForwards(u8, bytes, parsed.value.value.sessionId);
        self.sessionID = @as([]const u8, bytes);
    }
    fn navigateToSite(self: *Self, url: []const u8) !void {
        try self.logger.info("Driver::navigateToSite()::navigating to", url);
        const bufLen = 250;
        var urlBuf: [bufLen]u8 = undefined;
        const urlApi = try self.getRequestUrl(5, bufLen, &urlBuf);
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
    fn checkOptions(self: *Self, options: ?DriverTypes.Options) !void {
        if (options) |op| {
            try self.fileManager.createShFiles(op);
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
                const isCorrecrtVersion = (eql(u8, version, stable) or eql(u8, version, beta) or eql(u8, version, dev));
                if (!isCorrecrtVersion) {
                    try self.logger.warn("Driver::init()::incorrect chromeDeiver version specified defaulting to Stable...", null);
                } else {
                    self.chromeDriverVersion = op.chromeDriverVersion.?;
                }
            }
            if (op.chromeDriverExecPath) |path| {
                if (path.len > 0) self.chromeDriverExecPath = path;
            }
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
    fn getRequestUrl(self: *Self, key: u8, bufLen: comptime_int, buf: *[bufLen]u8) ![]const u8 {
        return try DriverTypes.RequestUrlPaths.getUrlPath(
            bufLen,
            buf,
            key,
            self.sessionID,
            self.chromeDriverPort,
        );
    }
    pub fn waitForDriver(self: *Self) !void {
        const seconds = 10_000_000_000;
        try self.logger.info("Driver::waitForDriver()::sleeping for 10 seconds waiting for driver to start....", null);
        std.time.sleep(seconds);
        _ = try Utils.checkIfPortInUse(self.allocator, self.chromeDriverPort);
        const MAX_RETRIES = 3;
        const waitSeconds = 15_000_000_000;
        var reTries: i32 = 0;
        while (!self.isDriverRunning) {
            if (MAX_RETRIES > 3) {
                @panic("Driver::waitForDriver()::failed to start chromeDriver, exiting program...");
            }
            try self.logger.info("Driver::waitForChromeDriver()::sending PING to chromeDriver...", null);
            const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
            var req = Http.init(self.allocator, null);
            var chromeDriverSessionFormatStringBuf: [100]u8 = undefined;
            const chromeDriverStatusFormattedURL = try Utils.formatString(100, &chromeDriverSessionFormatStringBuf, self.chromeDriverRestURL, .{ self.chromeDriverPort, "status" });
            const res = try req.get(chromeDriverStatusFormattedURL, .{ .server_header_buffer = serverHeaderBuf }, 245);
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
            std.time.sleep(waitSeconds);
        }
        if (self.isDriverRunning) {
            try self.logger.writeToStdOut();
        }
    }
};
