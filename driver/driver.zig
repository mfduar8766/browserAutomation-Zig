const std = @import("std");
const Http = @import("lib").Http;
const Logger = @import("lib").Logger;
const builtIn = @import("builtin");
const Types = @import("lib").Types;
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const Utils = @import("lib").Utils;
const DriverTypes = @import("./types.zig");
const process = std.process;

// kill -9 PID

fn runSetfilePermissionThread(driver: *Driver) !void {
    try driver.setFilePermissionsThread();
}

fn runStartChromeDriverThread(driver: *Driver) !void {
    try driver.startChromeDriverThread();
}

pub const Driver = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;
    const CHROME_DRIVER_DOWNLOAD_URL: []const u8 = "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json";
    comptime chromeDriverRestURL: []const u8 = "http://127.0.0.1:{d}/session",
    chromeDriverPort: i32 = 4444,
    allocator: Allocator,
    logger: Logger = undefined,
    chromeDriverVersion: []const u8 = Types.ChromeDriverVersion.getDriverVersion(0),
    chromeDriverExecPath: []const u8 = "",
    sessionID: []const u8 = "",
    isDriverRunning: bool = false,

    pub fn init(allocator: Allocator, logger: ?Logger, options: ?DriverTypes.Options) !Self {
        var driver = Driver{ .allocator = allocator };
        if (logger) |log| {
            driver.logger = log;
        } else {
            driver.logger = try Logger.init("Logs");
        }
        try driver.checkOptions(options);
        if (driver.chromeDriverExecPath.len == 0) {
            try driver.downloadChromeDriverVersionInformation();
        }
        return driver;
    }
    pub fn deInit(self: *Self) !void {
        self.logger.closeDirAndFiles();
    }
    pub fn launchWindow(self: *Self, url: []const u8) !void {
        try self.logger.info("Driver::launchWindow()::opening chromeDriver and navigating to:", url);
        try self.openDriver();
        // try self.navigateToURL(url);
    }
    fn checkOptions(self: *Self, options: ?DriverTypes.Options) !void {
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
    fn downloadChromeDriverVersionInformation(self: *Self) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 8696 });
        const body = try req.get(CHROME_DRIVER_DOWNLOAD_URL, .{ .server_header_buffer = serverHeaderBuf }, undefined);
        var buf: [1024 * 8]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{body.len});
        try self.logger.info("Driver::downloadChromeDriver()::successfully downloaded btypes", numAsString);
        const res = try std.json.parseFromSlice(Types.ChromeDriverResponse, self.allocator, body, .{ .ignore_unknown_fields = true });
        try self.downoadChromeDriverZip(res.value);
        defer {
            self.allocator.free(serverHeaderBuf);
            self.allocator.free(body);
            req.deinit();
            res.deinit();
        }
    }
    fn downoadChromeDriverZip(self: *Self, res: Types.ChromeDriverResponse) !void {
        var chromeDriverURL: []const u8 = "";
        const tag = getOsType();
        if (tag.len == 0 or eql(u8, tag, "UNKNOWN")) {
            try self.logger.fatal("Driver::downoadChromeDriverZip()::cannot find OSType", tag);
            @panic("Driver::downoadChromeDriverZip()::osType does not exist exiting program...");
        }
        for (res.channels.Stable.downloads.chromedriver) |driver| {
            if (eql(u8, driver.platform, tag)) {
                chromeDriverURL = driver.url;
                break;
            }
        }
        var arrayList = try std.ArrayList([]const u8).initCapacity(self.allocator, 100);
        defer arrayList.deinit();
        var t = std.mem.split(u8, chromeDriverURL, "/");
        while (t.next()) |value| {
            try arrayList.append(value);
        }
        const chromeDriverFileName = arrayList.items[arrayList.items.len - 1];
        if (chromeDriverFileName.len == 0 or eql(u8, chromeDriverFileName, "UNKNOWN")) {
            @panic("Driver::downoadChromeDriverZip()::wrong osType exiting program...");
        }
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
        defer self.allocator.free(serverHeaderBuf);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 10679494 });
        defer req.deinit();
        const body = try req.get(chromeDriverURL, .{ .server_header_buffer = serverHeaderBuf }, null);
        defer self.allocator.free(body);
        const file = try std.fs.cwd().createFile(
            chromeDriverFileName,
            .{ .read = true },
        );
        defer file.close();
        try file.writeAll(body);
        try file.seekTo(0);
        Utils.dirExists("chromeDriver") catch |e| {
            try self.logger.err("Driver::downoadChromeDriverZip()::chromeDriver folder does not exist creating folder", @errorName(e));
            try unZipChromeDriver(chromeDriverFileName);
        };
    }
    fn unZipChromeDriver(fileName: []const u8) !void {
        const cwd = Utils.getCWD();
        const file = try cwd.openFile(fileName, .{});
        defer file.close();
        try cwd.makeDir("chromeDriver");
        var dir = try cwd.openDir("chromeDriver", .{ .iterate = true });
        defer dir.close();
        var seek = file.seekableStream();
        var zipItter = try std.zip.Iterator(@TypeOf(seek)).init(seek);
        while (true) {
            const next = try zipItter.next();
            if (next) |entry| {
                if (entry.uncompressed_size == 0) continue;
                const totalOffSet = entry.filename_len + @sizeOf(std.zip.LocalFileHeader);
                try seek.seekTo(@intCast(totalOffSet));
                var buf: [1024]u8 = undefined;
                _ = try entry.extract(seek, .{}, &buf, dir);
            } else break;
        }
    }
    fn getOsType() []const u8 {
        return switch (builtIn.os.tag) {
            .macos => {
                const archType = builtIn.target.os.tag.archName(builtIn.cpu.arch);
                if (startsWith(u8, archType, "x")) {
                    return Types.PlatForms.getOS(2);
                }
                return Types.PlatForms.getOS(1);
            },
            .windows => {
                const archType = builtIn.target.os.tag.archName(builtIn.cpu.arch);
                if (startsWith(u8, archType, "32")) {
                    return Types.PlatForms.getOS(3);
                }
                return Types.PlatForms.getOS(4);
            },
            .linux => Types.PlatForms.getOS(0),
            else => "",
        };
    }
    fn getRequestUrl(self: *Self, key: u8) ![]const u8 {
        return try Types.RequestUrlPaths.getUrlPath(self.allocator, key, self.host, self.sessionID);
    }
    fn openDriver(self: *Self) !void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const allocator = arena.allocator();
        const fileName = "startChromeDriver.sh";
        const cwd = Utils.getCWD();
        const CWD_PATH = try cwd.realpathAlloc(allocator, ".");
        const logDir = self.logger.logDirPath;
        var logDirPathBuf: [50]u8 = undefined;
        const formattedLogDirPath = try Utils.formatString(&logDirPathBuf, "/{s}/driver.log", .{logDir});
        const chromeDriverLogFilePath = try Utils.concatStrings(allocator, CWD_PATH, formattedLogDirPath);

        var fileExists = true;
        Utils.fileExists(cwd, fileName) catch |e| {
            try self.logger.warn("Driver::openDriver()::error:", @errorName(e));
            fileExists = false;
        };
        if (fileExists) {
            try cwd.deleteFile(fileName);
        }

        var arrayList = try std.ArrayList(u8).initCapacity(allocator, 1024);
        var startChromeDriver = try cwd.createFile(fileName, .{});
        try startChromeDriver.chmod(777);
        var chromeDriverPathArray = std.ArrayList([]const u8).init(allocator);
        var splitChromePath = std.mem.split(u8, self.chromeDriverExecPath, "/");
        while (splitChromePath.next()) |next| {
            try chromeDriverPathArray.append(next);
        }
        const index = Utils.indexOf([][]const u8, chromeDriverPathArray.items, []const u8, "chromeDriver");
        if (index == -1) {
            @panic("Driver::openDriver()::cannot find chromeDriver folder, exiting program...");
        }

        const chromeDriverExec = chromeDriverPathArray.pop();
        const chromeDriverExecFolderIndex = chromeDriverPathArray.items[@as(usize, @intCast(index))..];
        const joinedPath = try std.mem.join(allocator, "/", chromeDriverExecFolderIndex);

        var buf1: [100]u8 = undefined;
        var buf2: [100]u8 = undefined;
        var buf3: [1024]u8 = undefined;
        const formattedDriverFolderPath = try Utils.formatString(&buf1, "cd \"{s}/\"\n", .{joinedPath});
        const formattedChmodX = try Utils.formatString(&buf2, "chmod +x ./{s}\n", .{chromeDriverExec});
        const formattedPort = try Utils.formatString(&buf3, "./{s} --port={d} --log-path={s}\n", .{
            chromeDriverExec,
            self.chromeDriverPort,
            chromeDriverLogFilePath,
        });

        _ = try arrayList.writer().write("#!/bin/bash\n");
        _ = try arrayList.writer().write(formattedDriverFolderPath);
        _ = try arrayList.writer().write(formattedChmodX);
        _ = try arrayList.writer().write(formattedPort);
        var bufWriter = std.io.bufferedWriter(startChromeDriver.writer());
        const writer = bufWriter.writer();
        _ = try writer.print("{s}\n", .{arrayList.items});
        try bufWriter.flush();

        const argv = [_][]const u8{
            "chmod",
            "+x",
            "./runDriver.sh",
        };
        var code = try Utils.executeCmds(3, self.allocator, &argv);
        try Utils.checkCode(code.exitCode, "Utils::checkCode()::cannot open chromeDriver, exiting program...");

        const arg2 = [_][]const u8{
            "./runDriver.sh",
        };
        code = try Utils.executeCmds(1, allocator, &arg2);
        try Utils.checkCode(code.exitCode, "Utils::checkCode()::cannot open chromeDriver, exiting program...");

        const response = try self.checkIfPortInUse(self.chromeDriverPort);
        self.logger.info("Driver::openDriver()::received response from checkIfPortInUse()::", response.message);
        if (!self.isDriverRunning) {
            self.isDriverRunning = !self.isDriverRunning;
            try self.logger.writeToStdOut();
        }
        // try cwd.deleteFile("startChromeDriver.sh");
        defer {
            allocator.free(CWD_PATH);
            allocator.free(chromeDriverLogFilePath);
            allocator.free(joinedPath);
            chromeDriverPathArray.deinit();
            startChromeDriver.close();
            arrayList.deinit();
            arena.deinit();
        }
    }
    fn navigateToURL(self: *Self, url: []const u8) !void {
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
        defer self.allocator.free(serverHeaderBuf);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 10679494 });
        defer req.deinit();
        var formatStringBuf: [100]u8 = undefined;
        const formattedURL = std.fmt.bufPrint(&formatStringBuf, self.chromeDriverRestURL, .{self.chromeDriverPort});
        std.debug.print("URL: {s}\n", .{url});
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var string = std.ArrayList(u8).init(fba.allocator());
        defer string.deinit();
        try std.json.stringify(DriverTypes.DriverOptions{ .capabilities = .{ .acceptInsecureCerts = true } }, .{}, string.writer());
        std.debug.print("POST-BODY: {s}\n", .{buf});
        const body = try req.post(formattedURL, std.http.Client.RequestOptions{
            .headers = .{ .content_type = .{ .override = "application/json" } },
            .redirect_behavior = .unhandled,
            .server_header_buffer = serverHeaderBuf,
        }, &buf);
        std.debug.print("BODY: {s}\n", .{body});
        defer self.allocator.free(body);
    }
};
