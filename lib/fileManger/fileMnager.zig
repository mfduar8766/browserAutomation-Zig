const std = @import("std");
const builtIn = @import("builtin");
const time = std.time;
const Logger = @import("../logger/logger.zig").Logger;
const Types = @import("../types/types.zig");
const Utils = @import("../utils/utils.zig");
const Http = @import("../http/http.zig").Http;

pub const Actions = enum {
    ///startChromeDriver - ./startChromeDriver.sh
    startChromeDriver,
    ///startDriverDetached - ./startDriverDetached.sh
    startDriverDetached,
    ///deleteDriverDetached - ./deleteDriverDetached.sh
    deleteDriverDetached,
    ///startUIDetached - ./startUIDetached.sh
    startUIDetached,
    ///startExampleUISh - ./startExampleUI.sh
    startExampleUISh,
    ///startE2eDetached - ./startE2eDetached.sh
    startE2eDetached,
    ///deleteE2eDetached - ./deleteE2eDetached.sh
    deleteE2eDetached,
    ///startE2eSh - ./startE2e.sh
    startE2eSh,
};

const Files = struct {
    ///startChromeDriverSh - ./startChromeDriver.sh
    comptime startChromeDriverSh: []const u8 = "./startChromeDriver.sh",
    ///startDriverDetachedSh - startDriverDetached.sh
    comptime startDriverDetachedSh: []const u8 = "./startDriverDetached.sh",
    ///createDeleteDriverDetachedSh - deleteDriverDetached.sh
    comptime createDeleteDriverDetachedSh: []const u8 = "./deleteDriverDetached.sh",
    ///startChromeDriverShW - .\\startChromeDriver.sh
    comptime startChromeDriverShW: []const u8 = ".\\startChromeDriver.sh",
    ///startDriverDetachedShW - .\\startDriverDetached.sh
    comptime startDriverDetachedShW: []const u8 = ".\\startDriverDetached.sh",
    ///deleteDriverDetachedShW - .\\deleteDriverDetached.sh
    comptime deleteDriverDetachedShW: []const u8 = ".\\deleteDriverDetached.sh",
    ///loggerFileDir = Logs
    loggerFileDir: []const u8 = "Logs",
    ///driverOutFile - driver.log
    comptime driverOutFile: []const u8 = "driver.log",
    ///screenShotDir - screenShots
    comptime screenShotDir: []const u8 = "screenShots",
    ///startExampleUISh - ./startUI.sh
    comptime startExampleUISh: []const u8 = "./startUI.sh",
    ///startExampleUIShW - .\\startUI.sh
    comptime startExampleUIShW: []const u8 = ".\\startUI.sh",
    ///startExampleDetachedSh - ./startExampleDetachedShW.sh
    comptime startExampleDetachedSh: []const u8 = "./startUIDetached.sh",
    ///startExampleDetachedShW - .\\startExampleDetachedShW.sh
    comptime startExampleDetachedShW: []const u8 = ".\\startUIDetached.sh",
    comptime electronFolder: []const u8 = "electron",
    comptime startE2eSh: []const u8 = "./startE2e.sh",
    comptime startE2eShW: []const u8 = ".\\startE2e.sh",
    comptime startE2eDetachedSh: []const u8 = "./startE2eDetached.sh",
    comptime startE2eDetachedShW: []const u8 = ".\\startE2eDetached.sh",
    comptime deleteE2eDetachedSh: []const u8 = "./deleteE2eDetached.sh",
    comptime deleteE2eDetachedShW: []const u8 = ".\\deleteE2eDetached.sh",
};

pub const FileManager = struct {
    const Self = @This();
    const chromeDriverSession: []const u8 = "chromeDriverSession";
    const E2eSession: []const u8 = "E2eSession";
    const chromedriver: []const u8 = "chromedriver";
    arena: std.heap.ArenaAllocator = undefined,
    logger: Logger = undefined,
    driverOutFile: std.fs.File = undefined,
    files: Files = Files{},
    screenShotsDir: std.fs.Dir = undefined,
    comptime osType: []const u8 = Utils.getOsType(),

    pub fn init(allocator: std.mem.Allocator) !Self {
        var fileManager = FileManager{
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
        fileManager.logger = Logger.init(fileManager.files.loggerFileDir) catch |e| {
            std.debug.print("FileManager::init()::received error: {s}\n", .{@errorName(e)});
            @panic("FileManager::init()::failed to init fileManager, exiting program...");
        };
        return fileManager;
    }
    pub fn deInit(self: *Self) void {
        self.arena.deinit();
        // self.driverOutFile.close();
        // self.screenShotsDir.close();
        // self.logger.closeDirAndFiles();
    }
    pub fn log(self: *Self, logType: Types.LogLevels, message: []const u8, data: anytype) !void {
        switch (logType) {
            Types.LogLevels.INFO => try self.logger.info(message, data),
            Types.LogLevels.WARNING => try self.logger.warn(message, data),
            Types.LogLevels.ERROR => try self.logger.err(message, data),
            Types.LogLevels.FATAL => try self.logger.fatal(message, data),
        }
    }
    pub fn createFiles(self: *Self, chromeDriverOptions: Types.ChromeDriverConfigOptions) !void {
        try self.createStartChromeDriverSh(chromeDriverOptions);
        try self.createStartDriverDetachedSh();
        try self.createDeleteDriverDetachedSh();
        try self.createScreenShotDir();
    }
    pub fn writeToStdOut(self: *Self) !void {
        var buf: [1024]u8 = undefined;
        const data = try self.logger.logDir.readFile(self.files.driverOutFile, &buf);
        const outw = std.io.getStdOut().writer();
        try outw.print("{s}\n", .{data});
    }
    pub fn executeFiles(self: *Self, fileName: []const u8) !void {
        if (comptime builtIn.os.tag == .windows) {
            const argv = [3][]const u8{
                "chmod",
                "+x",
                fileName,
            };
            var code = try Utils.executeCmds(3, self.getAllocator(), &argv);
            try Utils.checkExitCode(code.exitCode, "FileManager::executeFiles()::cannot open chromeDriver, exiting program...");
            const arg2 = [1][]const u8{
                fileName,
            };
            code = try Utils.executeCmds(1, self.getAllocator(), &arg2);
            try Utils.checkExitCode(code.exitCode, code.message);
        } else {
            const argv = [3][]const u8{
                "chmod",
                "+x",
                fileName,
            };
            var code = try Utils.executeCmds(3, self.getAllocator(), &argv);
            try Utils.checkExitCode(code.exitCode, "FileManager::executeFiles()::cannot open chromeDriver, exiting program...");
            const arg2 = [1][]const u8{
                fileName,
            };
            code = try Utils.executeCmds(1, self.getAllocator(), &arg2);
            try Utils.checkExitCode(code.exitCode, code.message);
        }
    }
    pub fn downloadChromeDriverVersionInformation(self: *Self, downloadURL: []const u8) !void {
        const serverHeaderBuf: []u8 = try self.getAllocator().alloc(u8, 1024 * 8);
        var req = Http.init(self.getAllocator(), .{ .maxReaderSize = 8696 });
        const body = try req.get(downloadURL, .{ .server_header_buffer = serverHeaderBuf }, undefined);
        var buf: [1024 * 8]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{body.len});
        try self.logger.info("FileManager::downloadChromeDriver()::successfully downloaded btypes", numAsString);
        const res = try std.json.parseFromSlice(Types.ChromeDriverResponse, self.getAllocator(), body, .{ .ignore_unknown_fields = true });
        try self.downoadChromeDriverZip(res.value);
        defer {
            self.getAllocator().free(serverHeaderBuf);
            self.getAllocator().free(body);
            req.deinit();
            res.deinit();
        }
    }
    pub fn saveScreenShot(self: *Self, fileName: ?[]const u8, bytes: []const u8) !void {
        var dest: [500000]u8 = undefined;
        try std.base64.standard.Decoder.decode(&dest, bytes);
        if (fileName) |name| {
            if (!std.mem.containsAtLeast(u8, name, 1, ".")) {
                @panic("FileManager::saveScreenShot()::file must contain .png|.jpeg|.txt|.log");
            }
            try Utils.deleteFileIfExists(self.screenShotsDir, name);
            const file = try self.screenShotsDir.createFile(name, .{});
            defer file.close();
            try file.writeAll(&dest);
        } else {
            try self.logger.warn("FileManager::saveScreenShot()::file extension type not supported default to .PNG", null);
            var buf: [100]u8 = undefined;
            const today = Utils.fromTimestamp(@intCast(time.timestamp()));
            var buf2: [10]u8 = undefined;
            const timeStr = try Utils.formatString(10, &buf2, "{d}_{d}_{d}", .{
                today.year,
                today.month,
                today.day,
            });
            const name = try Utils.createFileName(100, &buf, timeStr, .PNG);
            try Utils.deleteFileIfExists(self.screenShotsDir, name);
            const file = try self.screenShotsDir.createFile(name, .{});
            defer file.close();
            try file.writeAll(&dest);
        }
    }
    pub fn runExampleUI(self: *Self) !void {
        const startUIShFileData: []const u8 =
            \\#!/bin/bash
            \\echo "Change dir to UI and start node server..."
            \\cd "UI"
            \\npm run start
        ;
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startExampleUISh));
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startUIDetached));
        var startUiExampleFIle = try cwd.createFile(self.setShFileByOs(Actions.startExampleUISh), .{ .truncate = true });
        try startUiExampleFIle.chmod(777);
        try startUiExampleFIle.writeAll(startUIShFileData);
        var startExampleDetachedFile = try cwd.createFile(self.setShFileByOs(Actions.startUIDetached), .{ .truncate = true });
        try startExampleDetachedFile.chmod(777);
        const startUIDeatachedFileData = try createStartDetachedShFileData("startUI", "node", self.setShFileByOs(Actions.startExampleUISh));
        startExampleDetachedFile.writeAll(startUIDeatachedFileData) catch |e| {
            @panic(@errorName(e));
        };
        defer {
            startExampleDetachedFile.close();
            startUiExampleFIle.close();
        }
        const argv = [3][]const u8{
            "chmod",
            "+x",
            self.setShFileByOs(Actions.startUIDetached),
        };
        var code = try Utils.executeCmds(3, self.getAllocator(), &argv);
        try Utils.checkExitCode(code.exitCode, code.message);
        const arg2 = [1][]const u8{
            self.setShFileByOs(Actions.startUIDetached),
        };
        code = try Utils.executeCmds(1, self.getAllocator(), &arg2);
        try Utils.checkExitCode(code.exitCode, code.message);
    }
    pub fn startE2E(self: *Self, url: []const u8) !void {
        const cwd = Utils.getCWD();
        const CWD_PATH = try cwd.realpathAlloc(self.getAllocator(), ".");
        defer self.getAllocator().free(CWD_PATH);
        Utils.printLn("CWD: {s}\n", .{CWD_PATH});
        // try self.logger.info("FileManager::startE2E()::electron folder exists", null);
        // /Users/matheusduarte/Desktop/browserAutomation-Zig/e2e/deleteE2eDetached.sh

        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.deleteE2eDetached));
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startE2eSh));
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startE2eDetached));

        var deleteE2eDetached = try cwd.createFile(self.setShFileByOs(Actions.deleteE2eDetached), .{});
        try deleteE2eDetached.chmod(777);
        const deleteSession = try createDeleteDetachedShFileData(E2eSession, "node");
        deleteE2eDetached.writeAll(deleteSession) catch |err| {
            Utils.printLn("FileManager::startE2E()::Caught error: {}\n", .{err});
            @panic(@errorName(err));
        };
        var startE2eDetached = try cwd.createFile(self.setShFileByOs(Actions.startE2eDetached), .{});
        try startE2eDetached.chmod(777);
        const fileData = try createStartDetachedShFileData(E2eSession, "node", self.setShFileByOs(Actions.startE2eSh));
        startE2eDetached.writeAll(fileData) catch |e| {
            Utils.printLn("FileManager::startE2E()::Caught error: {}\n", .{e});
            @panic(@errorName(e));
        };
        const startE2eShBody: []const u8 =
            \\#!/bin/bash
            \\echo "starting E2E...\n"
            \\cd "{s}/dist/mac/E2E.app/Contents/MacOS/"
            \\./E2E --url={s} &
        ;
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        const formattedE2eFileData = try Utils.formatString(Utils.MAX_BUFF_SIZE, &buf, startE2eShBody, .{
            self.files.electronFolder,
            url,
        });
        var e2eFile = try cwd.createFile(self.setShFileByOs(Actions.startE2eSh), .{});
        try e2eFile.chmod(777);
        e2eFile.writeAll(formattedE2eFileData) catch |er| {
            @panic(@errorName(er));
        };
        try self.executeFiles(self.setShFileByOs(Actions.startE2eDetached));
        std.debug.print("Sleeping for 60 seconds...\n", .{});
        // std.time.sleep(5_000_000_000);
        Utils.sleep(60000);
        std.debug.print("Calling stop E2E...\n", .{});
        try self.executeFiles(self.setShFileByOs(Actions.deleteE2eDetached));
        defer e2eFile.close();
        defer deleteE2eDetached.close();
        defer startE2eDetached.close();
    }
    pub fn setShFileByOs(self: *Self, action: Actions) []const u8 {
        return switch (action) {
            Actions.startChromeDriver => {
                if (self.isWindows()) {
                    return self.files.startChromeDriverShW;
                }
                return self.files.startChromeDriverSh;
            },
            Actions.startDriverDetached => {
                if (self.isWindows()) {
                    return self.files.startDriverDetachedShW;
                }
                return self.files.startDriverDetachedSh;
            },
            Actions.startUIDetached => {
                if (self.isWindows()) {
                    return self.files.startExampleDetachedShW;
                }
                return self.files.startExampleDetachedSh;
            },
            Actions.startExampleUISh => {
                if (self.isWindows()) {
                    return self.files.startExampleUIShW;
                }
                return self.files.startExampleUISh;
            },
            Actions.deleteDriverDetached => {
                if (self.isWindows()) {
                    return self.files.deleteDriverDetachedShW;
                }
                return self.files.createDeleteDriverDetachedSh;
            },
            Actions.startE2eDetached => {
                if (self.isWindows()) {
                    return self.files.startE2eDetachedShW;
                }
                return self.files.startE2eDetachedSh;
            },
            Actions.deleteE2eDetached => {
                if (self.isWindows()) {
                    return self.files.deleteE2eDetachedShW;
                }
                return self.files.deleteE2eDetachedSh;
            },
            Actions.startE2eSh => {
                if (self.isWindows()) {
                    return self.files.startE2eShW;
                }
                return self.files.startE2eSh;
            },
        };
    }
    fn getAllocator(self: *Self) std.mem.Allocator {
        return self.arena.allocator();
    }
    fn isWindows(self: *Self) bool {
        if (Utils.startsWith(u8, self.osType, "win")) {
            return true;
        }
        return false;
    }
    fn downoadChromeDriverZip(self: *Self, res: Types.ChromeDriverResponse) !void {
        var chromeDriverURL: []const u8 = "";
        const tag = Utils.getOsType();
        if (tag.len == 0 or Utils.eql(u8, tag, "UNKNOWN")) {
            try self.logger.fatal("FileManager::downoadChromeDriverZip()::cannot find OSType", tag);
            @panic("FileManager::downoadChromeDriverZip()::osType does not exist exiting program...");
        }
        for (res.channels.Stable.downloads.chromedriver) |driver| {
            if (Utils.eql(u8, driver.platform, tag)) {
                chromeDriverURL = driver.url;
                break;
            }
        }
        var arrayList = try std.ArrayList([]const u8).initCapacity(self.getAllocator(), 100);
        defer arrayList.deinit();
        var t = std.mem.splitAny(u8, chromeDriverURL, "/");
        while (t.next()) |value| {
            try arrayList.append(value);
        }
        const chromeDriverFileName = arrayList.items[arrayList.items.len - 1];
        if (chromeDriverFileName.len == 0 or Utils.eql(u8, chromeDriverFileName, "UNKNOWN")) {
            @panic("FileManager::downoadChromeDriverZip()::wrong osType exiting program...");
        }
        const serverHeaderBuf: []u8 = try self.getAllocator().alloc(u8, 1024 * 8);
        defer self.getAllocator().free(serverHeaderBuf);
        var req = Http.init(self.getAllocator(), .{ .maxReaderSize = 10679494 });
        defer req.deinit();
        const body = try req.get(chromeDriverURL, .{ .server_header_buffer = serverHeaderBuf }, null);
        defer self.getAllocator().free(body);
        const file = try std.fs.cwd().createFile(
            chromeDriverFileName,
            .{ .read = true },
        );
        defer file.close();
        try file.writeAll(body);
        try file.seekTo(0);
        Utils.dirExists(Utils.getCWD(), "chromeDriver") catch |e| {
            try self.logger.err("FileManager::downoadChromeDriverZip()::chromeDriver folder does not exist creating folder", @errorName(e));
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
    fn createStartDriverDetachedSh(self: *Self) !void {
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startDriverDetached));
        var startDriverDetachedSh = try cwd.createFile(self.setShFileByOs(Actions.startDriverDetached), .{});
        try startDriverDetachedSh.chmod(777);
        const fileData = try createStartDetachedShFileData(chromeDriverSession, chromedriver, self.setShFileByOs(Actions.startChromeDriver));
        startDriverDetachedSh.writeAll(fileData) catch |e| {
            @panic(@errorName(e));
        };
        defer startDriverDetachedSh.close();
    }
    fn createDeleteDriverDetachedSh(self: *Self) !void {
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.deleteDriverDetached));
        var deleteDriverSessionDetachedSh = try cwd.createFile(self.setShFileByOs(Actions.deleteDriverDetached), .{});
        try deleteDriverSessionDetachedSh.chmod(777);
        const fileData = try createDeleteDetachedShFileData(chromeDriverSession, chromedriver);
        deleteDriverSessionDetachedSh.writeAll(fileData) catch |e| {
            @panic(@errorName(e));
        };
        defer deleteDriverSessionDetachedSh.close();
    }
    fn createDriverOutDir(self: *Self, logFilePath: ?[]const u8) ![]const u8 {
        var chromeDriverLogFilePath: []const u8 = "";
        if (logFilePath) |path| {
            chromeDriverLogFilePath = path;
        } else {
            try Utils.deleteFileIfExists(self.logger.logDir, self.files.driverOutFile);
            self.driverOutFile = try self.logger.logDir.createFile(self.files.driverOutFile, .{ .truncate = true });
            const CWD_PATH = try Utils.getCWD().realpathAlloc(self.getAllocator(), ".");
            defer self.getAllocator().free(CWD_PATH);
            const logDirName = self.logger.logDirPath;
            var logDirPathBuf: [100]u8 = undefined;
            const formattedLogDirPath = try Utils.formatString(100, &logDirPathBuf, "/{s}/{s}", .{
                logDirName,
                self.files.driverOutFile,
            });
            chromeDriverLogFilePath = @as([]const u8, try Utils.concatStrings(self.getAllocator(), CWD_PATH, formattedLogDirPath));
        }
        return chromeDriverLogFilePath;
    }
    fn createStartChromeDriverSh(self: *Self, chromeDriverOptions: Types.ChromeDriverConfigOptions) !void {
        const cwd = Utils.getCWD();
        const chromeDriverLogFilePath = try self.createDriverOutDir(chromeDriverOptions.chromeDriverOutFilePath);
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startChromeDriver));
        var startChromeDriver = try cwd.createFile(self.setShFileByOs(Actions.startChromeDriver), .{});
        try startChromeDriver.chmod(777);
        var chromeDriverPathArray = try std.ArrayList([]const u8).initCapacity(self.getAllocator(), 1024);
        var splitChromePath = std.mem.splitSequence(u8, chromeDriverOptions.chromeDriverExecPath.?, "/");
        while (splitChromePath.next()) |next| {
            try chromeDriverPathArray.append(next);
        }
        const chromeDriverExec = chromeDriverPathArray.pop();
        var exeFileName: []const u8 = "";
        if (chromeDriverExec) |exe| {
            exeFileName = exe;
            if (!Utils.eql(u8, exe, chromedriver)) {
                @panic("FileManager::createStartChromeDriverSh()::cannot find chromeDriver exe file, exiting program...");
            }
        }
        if (exeFileName.len == 0) {
            @panic("FileManager::createStartChromeDriverSh()::cannot find chromeDriver exe file, exiting program...");
        }
        const chromeDriverFolderPath = try std.mem.join(self.getAllocator(), "/", chromeDriverPathArray.items);
        var buf4: [1024]u8 = undefined;
        const fileContents =
            \\#!/bin/bash
            \\cd "{s}"
            \\chmod +x ./{s}
            \\./{s} --port={d} --log-path={s} --headless &
        ;
        const formattedFileContents = try Utils.formatString(1024, &buf4, fileContents, .{
            chromeDriverFolderPath,
            exeFileName,
            exeFileName,
            chromeDriverOptions.chromeDriverPort.?,
            chromeDriverLogFilePath,
        });
        _ = startChromeDriver.write(formattedFileContents) catch |e| {
            @panic(@errorName(e));
        };
        defer {
            self.getAllocator().free(chromeDriverLogFilePath);
            self.getAllocator().free(chromeDriverFolderPath);
            chromeDriverPathArray.deinit();
            startChromeDriver.close();
        }
    }
    fn createScreenShotDir(self: *Self) !void {
        const cwd = Utils.getCWD();
        Utils.dirExists(cwd, self.files.screenShotDir) catch |e| {
            try self.logger.err("FileManager::createScreenShotDir()", @errorName(e));
            self.screenShotsDir = try Utils.openDir(cwd, self.files.screenShotDir);
        };
        const res = Utils.makeDirPath(cwd, self.files.screenShotDir);
        if (!res.Ok) {
            try self.logger.err("FileManager::createScreenShotDir()::err", res.Err);
            @panic("FileManager::createScreenShotDir()::cannot create directory, exiting program...");
        }
        self.screenShotsDir = try Utils.openDir(cwd, self.files.screenShotDir);
    }
    fn createStartDetachedShFileData(
        comptime sessionTitle: []const u8,
        comptime serviceName: []const u8,
        fileToRun: []const u8,
    ) ![]const u8 {
        const fileData: []const u8 =
            \\#!/bin/bash
            \\echo "killing service: {s}..."
            \\pkill -9 {s}
            \\# Define the screen session title
            \\session_title="{s}"
            \\# Kill existing session with same title if it exists
            \\if screen -ls | grep -q "$session_title"; then
            \\  echo "screen $session_title is currently running, killing session and starting a new one"
            \\  screen -XS $session_title quit
            \\fi
            \\# Start a new screen session with the title $session_title and run the command to start the server
            \\screen -dmS $session_title bash -c "chmod +x {s} && {s}; exec bash"
        ;
        var buf: [1024]u8 = undefined;
        return try Utils.formatString(1024, &buf, fileData, .{ serviceName, serviceName, sessionTitle, fileToRun, fileToRun });
    }
    fn createDeleteDetachedShFileData(
        comptime sessionTitle: []const u8,
        comptime serviceName: []const u8,
    ) ![]const u8 {
        const fileData: []const u8 =
            \\#!/bin/bash
            \\# Define the title you're looking for
            \\session_title="{s}"
            \\# Get the session ID by matching the title
            \\echo "killing {s}..."
            \\pkill -9 {s}
            \\session_id=$(screen -ls | grep "$session_title" | awk '{s}' | cut -d'.' -f1)
            \\# Check if the session was found
            \\if [ -n "$session_id" ]; then
            \\  echo "Killing screen session: $session_id"
            \\  # Kill the screen session
            \\  screen -XS "$session_id" quit
            \\else
            \\echo "No screen session found with title: $session_title"
            \\fi
        ;
        var buf: [1024]u8 = undefined;
        return try Utils.formatString(1024, &buf, fileData, .{ sessionTitle, serviceName, serviceName, "{print $1}" });
    }
};
