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

// kill -9 PID
// p kill -9 chromedri

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
    driverLogFileDir: std.fs.Dir = undefined,
    driverLogFile: std.fs.File = undefined,

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
        try driver.openDriver();
        return driver;
    }
    pub fn deInit(self: *Self) !void {
        self.logger.closeDirAndFiles();
        self.driverLogFile.close();
        self.driverLogFileDir.close();
    }
    /// Used to open the browser and navigate to URL
    /// Example:
    ///     var driver = Driver.init(allocator, logger);
    ///     try driver.launchWindow("http://google.com");
    pub fn launchWindow(self: *Self, url: []const u8) !void {
        try self.logger.info("Driver::launchWindow()::opening chromeDriver and navigating to:", url);
        const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
        defer self.allocator.free(serverHeaderBuf);
        var req = Http.init(self.allocator, .{ .maxReaderSize = 1024 });
        defer req.deinit();
        var chromeDriverSessionFormatStringBuf: [100]u8 = undefined;
        const chromeDriverSessionFormattedURL = try Utils.formatString(100, &chromeDriverSessionFormatStringBuf, self.chromeDriverRestURL, .{
            self.chromeDriverPort,
        });
        try self.logger.info("Driver::navigateToURL()::using chromeDriver session url", chromeDriverSessionFormattedURL);
        try self.logger.info("Driver::navigateToURL()::navigating to", url);

        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var arrayList = std.ArrayList(u8).init(fba.allocator());
        defer arrayList.deinit();
        try std.json.stringify(Types.ChromeCapabilities{ .capabilities = .{ .acceptInsecureCerts = true } }, .{}, arrayList.writer());
        const options = std.http.Client.RequestOptions{
            .server_header_buffer = serverHeaderBuf,
            .headers = .{ .content_type = .{ .override = "application/json" } },
        };
        const body = try req.post(chromeDriverSessionFormattedURL, options, arrayList.items, 893);
        const parsed = try std.json.parseFromSlice(DriverTypes.Session, self.allocator, body, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();
        defer self.allocator.free(body);

        var sessionBuf: [32]u8 = undefined;
        var fbaSessionID = std.heap.FixedBufferAllocator.init(&sessionBuf);
        const fbaAllocator = fbaSessionID.allocator();
        const sessionID = try Utils.concatStrings(fbaAllocator, parsed.value.value.sessionId, "");
        self.sessionID = sessionID;
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
        Utils.dirExists(Utils.getCWD(), "chromeDriver") catch |e| {
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
        return switch (comptime builtIn.os.tag) {
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
        const chromeDriverLogOutFile = "driver.log";
        const cwd = Utils.getCWD();
        const CWD_PATH = try cwd.realpathAlloc(allocator, ".");
        const logDir = self.logger.logDirPath;
        var logDirPathBuf: [100]u8 = undefined;
        const formattedLogDirPath = try Utils.formatString(100, &logDirPathBuf, "/{s}/driver.log", .{logDir});
        std.debug.print("FORMATTED-LOG-DIR-OATH: {s}\n", .{formattedLogDirPath});
        const chromeDriverLogFilePath = try Utils.concatStrings(allocator, CWD_PATH, formattedLogDirPath);

        std.debug.print("LOG-FILE-DRIVER-PATH: {s}\n", .{chromeDriverLogFilePath});

        self.driverLogFileDir = try cwd.openDir(self.logger.logDirPath, .{
            .access_sub_paths = true,
            .iterate = true,
        });
        var driverLogFileExists = true;
        Utils.fileExists(self.driverLogFileDir, chromeDriverLogOutFile) catch |e| {
            try self.logger.warn("Driver::openDriver()::error::", @errorName(e));
            switch (e) {
                error.FileNotFound => {
                    driverLogFileExists = false;
                    try self.logger.warn("Driver::openDriver()::", @errorName(e));
                },
                else => {
                    try self.logger.info("Driver::openDriver()::runDriver.sh exists, deleting file and re creating it", null);
                },
            }
        };
        if (driverLogFileExists) {
            std.debug.print("DELTE DRIVER.LOG\n", .{});
            try self.driverLogFileDir.deleteFile(chromeDriverLogOutFile);
        }
        self.driverLogFile = try self.driverLogFileDir.createFile(chromeDriverLogOutFile, .{ .truncate = true });
        try self.driverLogFile.chmod(777);

        var fileExists = true;
        Utils.fileExists(cwd, fileName) catch |e| {
            try self.logger.warn("Driver::openDriver()::error::", @errorName(e));
            switch (e) {
                error.FileNotFound => {
                    fileExists = false;
                    try self.logger.warn("Driver::openDriver()::", @errorName(e));
                },
                else => {
                    try self.logger.info("Driver::openDriver()::runDriver.sh exists, deleting file and re creating it", null);
                },
            }
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
        const chromeDriverFolderPath = try std.mem.join(allocator, "/", chromeDriverExecFolderIndex);
        var buf1: [100]u8 = undefined;
        var buf2: [100]u8 = undefined;
        var buf3: [1024]u8 = undefined;
        const formattedDriverFolderPath = try Utils.formatString(100, &buf1, "cd \"{s}/\"\n", .{chromeDriverFolderPath});
        const formattedChmodX = try Utils.formatString(100, &buf2, "chmod +x ./{s}\n", .{chromeDriverExec});
        const formattedChromeDriverExeCall = try Utils.formatString(1024, &buf3, "./{s} --port={d} --log-path={s} &\n", .{
            chromeDriverExec,
            self.chromeDriverPort,
            chromeDriverLogFilePath,
        });

        _ = try arrayList.writer().write("#!/bin/bash\n");
        _ = try arrayList.writer().write(formattedDriverFolderPath);
        _ = try arrayList.writer().write(formattedChmodX);
        _ = try arrayList.writer().write(formattedChromeDriverExeCall);
        _ = try arrayList.writer().write("P1=$!\n");
        _ = try arrayList.writer().write("wait $P1\n");
        var bufWriter = std.io.bufferedWriter(startChromeDriver.writer());
        const writer = bufWriter.writer();
        _ = try writer.print("{s}\n", .{arrayList.items});
        try bufWriter.flush();

        defer {
            allocator.free(CWD_PATH);
            allocator.free(chromeDriverLogFilePath);
            allocator.free(chromeDriverFolderPath);
            chromeDriverPathArray.deinit();
            startChromeDriver.close();
            arrayList.deinit();
            arena.deinit();
        }
        const argv = [_][]const u8{
            "chmod",
            "+x",
            "./startChromeDriver.sh",
        };
        var code = try Utils.executeCmds(3, allocator, &argv);
        try Utils.checkExitCode(code.exitCode, "Utils::checkExitCode()::cannot open chromeDriver, exiting program...");
        const arg2 = [_][]const u8{
            "./startChromeDriver.sh",
        };
        code = try Utils.executeCmds(1, allocator, &arg2);
        try Utils.checkExitCode(code.exitCode, code.message);

        try self.logger.info("Driver::openDriver()::sleeping for 10 seconds waiting for driver to start....", null);
        std.time.sleep(10_000_000_000);

        const response = try Utils.checkIfPortInUse(allocator, self.chromeDriverPort);
        if (!self.isDriverRunning and response.exitCode == 0) {
            self.isDriverRunning = !self.isDriverRunning;
            var portBuf: [7]u8 = undefined;
            const portStr = try Utils.formatString(7, &portBuf, "{d}", .{self.chromeDriverPort});
            try self.logger.info("Driver::openDriver()::", portStr);
        }
        try self.logger.info("Driver::openDriver()::received response from checkIfPortInUse()::", response.message);
        if (!self.isDriverRunning) {
            self.isDriverRunning = !self.isDriverRunning;
            try self.logger.writeToStdOut();
        }

        // var arrayList = try std.ArrayList(u8).initCapacity(allocator, 1024);
        // var createRunDriverSh = cwd.createFile(fileName, .{}) catch |e| {
        //     try self.logger.warn("Driver::openDriver()::received error", @errorName(e));
        //     @panic("Driver::openDriver()::received error while trying to create file, exiting program...");
        // };
        // try createRunDriverSh.chmod(777);
        // var chromeDriverPathArray = std.ArrayList([]const u8).init(allocator);
        // var splitChromePath = std.mem.split(u8, self.chromeDriverExecPath, "/");
        // while (splitChromePath.next()) |next| {
        //     try chromeDriverPathArray.append(next);
        // }
        // const index = Utils.indexOf([][]const u8, chromeDriverPathArray.items, []const u8, "chromeDriver");
        // if (index == -1) {
        //     @panic("Driver::openDriver()::cannot find chromeDriver folder, exiting program...");
        // }

        // const chromeDriverExecFolderIndex = chromeDriverPathArray.items[@as(usize, @intCast(index))..];
        // const pathToChromeDriverExec = try std.mem.join(allocator, "/", chromeDriverExecFolderIndex);
        // var buf1: [100]u8 = undefined;
        // var buf2: [1024]u8 = undefined;
        // const changeToRunDriverFolder = try Utils.formatString(100, &buf1, "cd \"{s}/\"\n", .{"runDriver"});
        // const runZigBuild = try Utils.formatString(1024, &buf2, "(zig build run -DchromeDriverPort={d} -DchromeDriverExecPath={s} &)\n", .{
        //     self.chromeDriverPort,
        //     pathToChromeDriverExec,
        // });

        // _ = try arrayList.writer().write("#!/bin/bash\n\n");
        // _ = try arrayList.writer().write("echo \"Cd into runDriver dir and running zig build run..\"\n");
        // _ = try arrayList.writer().write(changeToRunDriverFolder);
        // _ = try arrayList.writer().write("zig build test\n");
        // _ = try arrayList.writer().write(runZigBuild);
        // var bufWriter = std.io.bufferedWriter(createRunDriverSh.writer());
        // const writer = bufWriter.writer();
        // _ = try writer.print("{s}\n", .{arrayList.items});
        // try bufWriter.flush();

        // const argv = [_][]const u8{
        //     "chmod",
        //     "+x",
        //     "./runDriver.sh",
        // };
        // var code = try Utils.executeCmds(3, self.allocator, &argv);
        // try Utils.checkExitCode(code.exitCode, "Utils::checkExitCode()::cannot open chromeDriver, exiting program...");

        // const arg2 = [_][]const u8{
        //     "./runDriver.sh",
        // };
        // code = try Utils.executeCmds(1, allocator, &arg2);
        // try Utils.checkExitCode(code.exitCode, "Utils::checkExitCode()::cannot open chromeDriver, exiting program...");
        // try self.logger.info("Driver::openDriver()::sleeping for 3 seconds waiting for driver to start....", null);
        // std.time.sleep(3_000_000_000);

        // const response = try Utils.checkIfPortInUse(allocator, self.chromeDriverPort);
        // if (!self.isDriverRunning and response.exitCode == 0) {
        //     self.isDriverRunning = !self.isDriverRunning;
        //     var portBuf: [7]u8 = undefined;
        //     const portStr = try Utils.formatString(7, &portBuf, "{d}", .{self.chromeDriverPort});
        //     try self.logger.info("Driver::openDriver()::", portStr);
        // }
        // try self.logger.info("Driver::openDriver()::received response from checkIfPortInUse()::", response.message);
        // if (!self.isDriverRunning) {
        //     self.isDriverRunning = !self.isDriverRunning;
        //     try self.logger.writeToStdOut();
        // }
        // try cwd.deleteFile(fileName);
        // defer {
        //     allocator.free(CWD_PATH);
        //     allocator.free(chromeDriverLogFilePath);
        //     allocator.free(pathToChromeDriverExec);
        //     chromeDriverPathArray.deinit();
        //     createRunDriverSh.close();
        //     arrayList.deinit();
        //     arena.deinit();
        // }
    }
    // fn navigateToURL(self: *Self, url: []const u8) !void {
    //     const serverHeaderBuf: []u8 = try self.allocator.alloc(u8, 1024 * 8);
    //     defer self.allocator.free(serverHeaderBuf);
    //     var req = Http.init(self.allocator, .{ .maxReaderSize = 1024 });
    //     defer req.deinit();
    //     var chromeDriverSessionFormatStringBuf: [100]u8 = undefined;
    //     const chromeDriverSessionFormattedURL = try Utils.formatString(100, &chromeDriverSessionFormatStringBuf, self.chromeDriverRestURL, .{
    //         self.chromeDriverPort,
    //     });
    //     try self.logger.info("Driver::navigateToURL()::using chromeDriver session url", chromeDriverSessionFormattedURL);
    //     try self.logger.info("Driver::navigateToURL()::navigating to", url);

    //     var buf: [1024]u8 = undefined;
    //     var fba = std.heap.FixedBufferAllocator.init(&buf);
    //     var arrayList = std.ArrayList(u8).init(fba.allocator());
    //     defer arrayList.deinit();
    //     try std.json.stringify(Types.ChromeCapabilities{ .capabilities = .{ .acceptInsecureCerts = true } }, .{}, arrayList.writer());
    //     const options = std.http.Client.RequestOptions{
    //         .server_header_buffer = serverHeaderBuf,
    //         .headers = .{ .content_type = .{ .override = "application/json" } },
    //     };
    //     const body = try req.post(chromeDriverSessionFormattedURL, options, arrayList.items, null);
    //     const parsed = try std.json.parseFromSlice(DriverTypes.Session, self.allocator, body, .{ .ignore_unknown_fields = true });
    //     defer parsed.deinit();
    //     defer self.allocator.free(body);
    //     self.sessionID = parsed.value.value.sessionId;
    // }
};
