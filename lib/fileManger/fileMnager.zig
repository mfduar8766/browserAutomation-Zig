const std = @import("std");
const builtIn = @import("builtin");
const time = std.time;
const Logger = @import("../logger/logger.zig").Logger;
const Types = @import("../types/types.zig");
const Utils = @import("../utils/utils.zig");
const Http = @import("../http/http.zig").Http;
const TestSuites = @import("testSuites.zig").TestSuites;
const AllocatingWriter = std.io.Writer.Allocating;

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
    ///buildAndInstallSh - ./buildAndInstall.sh
    buildAndInstallSh,
    ///state.json - State for the E2E
    stateJSON,
    ///deleteExampleUiDetached - ./deleteExampleUiDetached.sh
    deleteExampleUiDetached,
    ///checkPortInUse.sh
    checkPortInUse,
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
    comptime startExampleUISh: []const u8 = "./startExampleUISh.sh",
    ///startExampleUIShW - .\\startUI.sh
    comptime startExampleUIShW: []const u8 = ".\\startExampleUISh.sh",
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
    ///e2eRunner - E2e nodeJS process name
    comptime e2eRunner: []const u8 = "e2e-runner",
    comptime electronBuildPath: []const u8 = "dist/mac/E2E.app/Contents/MacOS",
    comptime buildAndInstallSh: []const u8 = "./buildAndInstall.sh",
    comptime buildAndInstallShW: []const u8 = ".\\buildAndInstall.sh",
    comptime stateJSON: []const u8 = "./state.json",
    comptime stateJSON_W: []const u8 = ".\\state.json",
    ///exampleUIAppName - Example UI app node process name
    comptime exampleUIAppName: []const u8 = "example-ui-app",
    comptime deleteExampleUiDetachedSH: []const u8 = "./deleteExampleUIDetached.sh",
    comptime deleteExampleUiDetachedSHW: []const u8 = ".\\deleteExampleUIDetached.sh",
    comptime checkPortInUseSh: []const u8 = "./checkPortInUse.sh",
    comptime checkPortInUseSHW: []const u8 = "\\.checkPortInUse.sh",
};

pub const FileManager = struct {
    const Self = @This();
    const chromeDriverSession: []const u8 = "chromeDriverSession";
    const E2eSession: []const u8 = "E2eSession";
    const chromedriver: []const u8 = "chromedriver";
    const ExampleUiSession: []const u8 = "ExampleUiSession";
    const localHost: []const u8 = "http://127.0.0.1:3000";
    arena: std.heap.ArenaAllocator = undefined,
    logger: *Logger = undefined,
    driverOutFile: ?std.fs.File = null,
    files: Files = Files{},
    screenShotsDir: ?std.fs.Dir = null,
    comptime osType: []const u8 = Utils.getOsType(),
    // stateJsonFile: ?std.fs.File = null,
    testSuites: ?TestSuites = null,
    isE2eRunning: bool = false,
    isExampleUiRunning: bool = false,

    pub fn init(allocator: std.mem.Allocator, runningE2E: bool) !*Self {
        const fileManager = try allocator.create(Self);
        fileManager.* = Self{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .isE2eRunning = runningE2E,
        };
        fileManager.logger = Logger.init(allocator, fileManager.files.loggerFileDir) catch |e| {
            try fileManager.log(Types.LogLevels.FATAL, "FileManager::init()::failed to initialize state: {s}", @errorName(e));
            @panic("FileManager::init()::failed to init fileManager, exiting program...");
        };
        if (fileManager.isE2eRunning) {
            try fileManager.logger.info("FileManager::init()::running E2E suite", null);
            fileManager.setUp() catch |er| {
                try fileManager.log(Types.LogLevels.FATAL, "FileManager::init()::failed to initialize state: {s}", @errorName(er));
                defer fileManager.deinit();
                @panic("FileManager::inint()::failed to initialize state");
            };
        }
        return fileManager;
    }
    fn setUp(self: *Self) !void {
        self.testSuites = TestSuites.init(self.arena.allocator()) catch |err| {
            try self.log(
                Types.LogLevels.ERROR,
                "FileManager::setUp::()::state::init()::received error: {s}",
                @errorName(err),
            );
            defer self.deinit();
            return err;
        };
        // const cwd = Utils.getCWD();
        // Utils.fileExists(cwd, self.setShFileByOs(Actions.stateJSON)) catch |e| {
        //     if (e == Utils.Errors.FileNotFound) {
        //         //TODO: NOT SURE IF WE DO THIS ON START OR JUST WHEN EACH FUNC IS CALLED
        //         // try self.handleFileDeletion();
        //         // try self.handleFileCreation();
        //         self.stateJsonFile = try cwd.createFile(self.setShFileByOs(Actions.stateJSON), .{});
        //         try self.stateJsonFile.?.chmod(0o775);
        //         const json = try Utils.stringify(self.getAllocator(), self.testSuites.?.state, .{
        //             .emit_null_optional_fields = true,
        //         });
        //         defer self.getAllocator().free(json);
        //         self.stateJsonFile.?.writeAll(json) catch |errr| {
        //             return errr;
        //         };
        //     } else {
        //         defer self.deinit();
        //         return e;
        //     }
        // };
        // self.stateJsonFile = cwd.openFile(self.setShFileByOs(Actions.stateJSON), .{
        //     .mode = .read_write,
        // }) catch |err| {
        //     defer self.deinit();
        //     return err;
        // };
        // try self.stateJsonFile.?.chmod(0o775);
        // const fileStat = self.stateJsonFile.?.stat() catch |er| {
        //     defer self.deinit();
        //     return er;
        // };
        // if (fileStat.size == 0) {
        //     const json = try Utils.stringify(self.getAllocator(), self.state.?.state, .{
        //         .emit_null_optional_fields = true,
        //         .whitespace = .indent_2,
        //     });
        //     defer self.getAllocator().free(json);
        //     self.stateJsonFile.?.writeAll(json) catch |errr| {
        //         return errr;
        //     };
        // }
    }
    pub fn deinit(self: *Self) void {
        if (self.driverOutFile != null) {
            self.driverOutFile.?.close();
        }
        if (self.screenShotsDir != null) {
            self.screenShotsDir.?.close();
        }
        // if (self.stateJsonFile != null) {
        //     self.stateJsonFile.?.close();
        // }
        self.logger.deinit();
        if (self.testSuites != null) {
            self.testSuites.?.deinit();
        }
        self.arena.deinit();
        const allocator = self.arena.child_allocator;
        allocator.destroy(self);
    }
    pub fn log(self: *Self, logType: Types.LogLevels, comptime message: []const u8, data: anytype) !void {
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
        //TODO:MAYBE CALL CREATE FILE FOR ALL SH FILES HERE
    }
    pub fn writeToStdOut(self: *Self) !void {
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        const data = try self.logger.logDir.readFile(self.files.driverOutFile, &buf);
        var stdout_writer = std.fs.File.stdout().writer(&buf);
        const stdout = &stdout_writer.interface;
        try stdout.print("{s}\n", .{data});
        try stdout.flush(); // Don't forget to flush!
        // const outw = std.io.getStdOut().writer();
        // try outw.print("{s}\n", .{data});
    }
    pub fn executeFiles(self: *Self, fileName: []const u8, needExecution: bool) !void {
        if (comptime builtIn.os.tag == .windows) {
            if (needExecution) {
                const argv = [3][]const u8{
                    "chmod",
                    "+x",
                    fileName,
                };
                const code = try Utils.executeCmds(argv.len, self.getAllocator(), &argv, fileName);
                try Utils.checkExitCode(code.exitCode, code.message);
            }
            const arg2 = [1][]const u8{
                fileName,
            };
            const code = try Utils.executeCmds(arg2.len, self.getAllocator(), &arg2, fileName);
            try Utils.checkExitCode(code.exitCode, code.message);
        } else {
            if (needExecution) {
                const argv = [3][]const u8{
                    "chmod",
                    "+x",
                    fileName,
                };
                const code = try Utils.executeCmds(argv.len, self.getAllocator(), &argv, fileName);
                try Utils.checkExitCode(code.exitCode, code.message);
            }
            const arg2 = [1][]const u8{
                fileName,
            };
            const code = try Utils.executeCmds(arg2.len, self.getAllocator(), &arg2, fileName);
            try Utils.checkExitCode(code.exitCode, code.message);
        }
    }
    pub fn downloadChromeDriverVersionInformation(self: *Self, downloadURL: []const u8) !void {
        var req = Http.init(self.getAllocator(), self.logger);
        req.deinit();
        const headers = std.http.Client.Request.Headers{};
        const body = try req.makeRequest(
            downloadURL,
            .GET,
            headers,
            null,
        );
        self.getAllocator().free(body);
        var buf: [Utils.MAX_BUFF_SIZE * 8]u8 = undefined;
        const numAsString = try std.fmt.bufPrint(&buf, "{}", .{body.len});
        try self.log(Types.LogLevels.INFO, "FileManager::downloadChromeDriver()::successfully downloaded btypes: {s}", numAsString);
        const res = try std.json.parseFromSlice(Types.ChromeDriverResponse, self.getAllocator(), body, .{ .ignore_unknown_fields = true });
        res.deinit();
        try self.downoadChromeDriverZip(res.value);
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
            try self.log(Types.LogLevels.WARNING, "FileManager::saveScreenShot()::file extension type not supported default to .PNG", null);
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
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startExampleUISh));
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startUIDetached));
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.deleteExampleUiDetached));

        var deleteExampleUiDetachedFile = try cwd.createFile(self.setShFileByOs(Actions.deleteExampleUiDetached), .{});
        defer deleteExampleUiDetachedFile.close();
        try deleteExampleUiDetachedFile.chmod(0o775);
        const deleteExampleUiFileData = try createDeleteDetachedShFileData(
            self.getAllocator(),
            ExampleUiSession,
            self.files.exampleUIAppName,
        );
        defer self.getAllocator().free(deleteExampleUiFileData);
        Utils.writeAllToFile(deleteExampleUiDetachedFile, deleteExampleUiFileData) catch |e| {
            @panic(@errorName(e));
        };
        const startExampleUIShFileData: []const u8 =
            \\#!/bin/bash
            \\echo "Change dir to UI and start node server..."
            \\cd "UI"
            \\npm run build
            \\
        ;
        var startUiExampleFIle = try cwd.createFile(self.setShFileByOs(Actions.startExampleUISh), .{});
        try startUiExampleFIle.chmod(0o775);
        Utils.writeAllToFile(startUiExampleFIle, startExampleUIShFileData) catch |er| {
            @panic(@errorName(er));
        };
        startUiExampleFIle.close();
        var startExampleDetachedFile = try cwd.createFile(self.setShFileByOs(Actions.startUIDetached), .{});
        try startExampleDetachedFile.chmod(0o775);
        const startUIDetachedFileData = try createStartDetachedShFileData(
            self.getAllocator(),
            ExampleUiSession,
            self.files.exampleUIAppName,
            self.setShFileByOs(Actions.startExampleUISh),
        );
        defer self.getAllocator().free(startUIDetachedFileData);
        Utils.writeAllToFile(startExampleDetachedFile, startUIDetachedFileData) catch |err| {
            @panic(@errorName(err));
        };
        startExampleDetachedFile.close();
        try self.executeFiles(self.setShFileByOs(Actions.startUIDetached), false);
        try self.log(Types.LogLevels.INFO, "FileManager::runExampleUI()::starting exampleUI...", null);
        self.isExampleUiRunning = true;
    }
    pub fn stopExampleUI(self: *Self) !void {
        if (self.isExampleUiRunning) {
            try self.log(Types.LogLevels.INFO, "FileManager::stopExampleUI()", null);
            try self.executeFiles(self.setShFileByOs(Actions.deleteExampleUiDetached), false);
            self.isExampleUiRunning = false;
        } else {
            try self.log(Types.LogLevels.INFO, "FileManager::stopExampleUI()::no UI running.", null);
        }
    }
    pub fn startE2E(self: *Self, url: ?[]const u8) !void {
        const cwd = Utils.getCWD();
        const CWD_PATH = try cwd.realpathAlloc(self.getAllocator(), ".");
        defer self.getAllocator().free(CWD_PATH);
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.deleteE2eDetached));
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startE2eSh));
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startE2eDetached));
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.buildAndInstallSh));
        self.buildAndInstall(cwd, CWD_PATH) catch |e| {
            try self.log(Types.LogLevels.ERROR, "FileManager::startE2E()::received error: {s}", .{@errorName(e)});
            @panic(@errorName(e));
        };
        var deleteE2eDetachedFile = try cwd.createFile(self.setShFileByOs(Actions.deleteE2eDetached), .{});
        defer deleteE2eDetachedFile.close();
        try deleteE2eDetachedFile.chmod(0o775);
        const deleteSessionData = try createDeleteDetachedShFileData(
            self.getAllocator(),
            E2eSession,
            self.files.e2eRunner,
        );
        defer self.getAllocator().free(deleteSessionData);
        Utils.writeAllToFile(deleteE2eDetachedFile, deleteSessionData) catch |err| {
            Utils.printLn("FileManager::startE2E()::received error", .{err});
            @panic(@errorName(err));
        };
        var startE2eDetached = try cwd.createFile(self.setShFileByOs(Actions.startE2eDetached), .{});
        try startE2eDetached.chmod(0o775);
        const startE2eDetachedFileData = try createStartDetachedShFileData(
            self.getAllocator(),
            E2eSession,
            self.files.e2eRunner,
            self.setShFileByOs(
                Actions.startE2eSh,
            ),
        );
        defer self.getAllocator().free(startE2eDetachedFileData);
        Utils.writeAllToFile(startE2eDetached, startE2eDetachedFileData) catch |e| {
            try self.log(Types.LogLevels.ERROR, "FileManager::startE2E()::Caught error: {s}", .{@errorName(e)});
            @panic(@errorName(e));
        };
        startE2eDetached.close();
        const startE2eShBody: []const u8 =
            \\#!/bin/bash
            \\echo "starting E2E...\n"
            \\cd "{s}/{s}/"
            \\exec -a {s} ./E2E --url={s} &
            \\
        ;
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        const formattedE2eFileData = try Utils.formatStringAndCopy(
            self.getAllocator(),
            Utils.MAX_BUFF_SIZE,
            &buf,
            startE2eShBody,
            .{
                self.files.electronFolder,
                self.files.electronBuildPath,
                self.files.e2eRunner,
                if (self.isExampleUiRunning) localHost else url.?,
            },
        );
        defer self.getAllocator().free(formattedE2eFileData);
        var e2eFile = try cwd.createFile(self.setShFileByOs(Actions.startE2eSh), .{});
        try e2eFile.chmod(0o775);
        Utils.writeAllToFile(e2eFile, formattedE2eFileData) catch |er| {
            @panic(@errorName(er));
        };
        e2eFile.close();
        try self.executeFiles(self.setShFileByOs(Actions.startE2eDetached), false);
        try self.log(Types.LogLevels.INFO, "FileManager::startE2E()::starting e2e...", null);
        self.isE2eRunning = true;
    }
    pub fn stopE2E(self: *Self) !void {
        if (self.isE2eRunning) {
            try self.log(Types.LogLevels.INFO, "FileManager::stopE2E()", null);
            try self.executeFiles(self.setShFileByOs(Actions.deleteE2eDetached), false);
            self.isE2eRunning = false;
        } else {
            try self.log(Types.LogLevels.INFO, "FileManager::stopE2E()::no e2e running.", null);
        }
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
            Actions.buildAndInstallSh => {
                if (self.isWindows()) {
                    return self.files.buildAndInstallShW;
                }
                return self.files.buildAndInstallSh;
            },
            Actions.stateJSON => {
                if (self.isWindows()) {
                    return self.files.stateJSON_W;
                }
                return self.files.stateJSON;
            },
            Actions.deleteExampleUiDetached => {
                if (self.isWindows()) {
                    return self.files.deleteExampleUiDetachedSHW;
                }
                return self.files.deleteExampleUiDetachedSH;
            },
            Actions.checkPortInUse => {
                if (self.isWindows()) {
                    return self.files.checkPortInUseSHW;
                }
                return self.files.checkPortInUseSh;
            },
        };
    }
    pub fn runSelectedTest(self: *Self, testName: []const u8) !void {
        if (self.testSuites != null) {
            try self.testSuites.?.runSelectedTest(testName);
        }
    }
    ///TODO:NOT SURE IF THIS IS NEEDED...
    pub fn createCheckIfPortInUse(self: *Self, port: i32) !void {
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.checkPortInUse));
        var file = try cwd.createFile(self.setShFileByOs(Actions.checkPortInUse), .{});
        try file.chmod(0o775);
        const body: []const u8 =
            \\#!/bin/bash
            \\PORT={d}
            \\if lsof -i :$PORT > /dev/null 2>&1; then
            \\  # Port is in use
            \\  exit 1
            \\else
            \\  # Port is not in use
            \\  exit 0
            \\fi
        ;
        var buf: [100]u8 = undefined;
        const formattedBody = try Utils.formatStringAndCopy(self.getAllocator(), Utils.MAX_BUFF_SIZE, &buf, body, .{port});
        defer self.getAllocator().free(formattedBody);
        Utils.writeAllToFile(file, formattedBody) catch |e| {
            @panic(@errorName(e));
        };
        file.close();
        try self.executeFiles(self.setShFileByOs(Actions.checkPortInUse), false);
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
            try self.log(Types.LogLevels.FATAL, "FileManager::downoadChromeDriverZip()::cannot find OSType: {s}", tag);
            @panic("FileManager::downoadChromeDriverZip()::osType does not exist exiting program...");
        }
        for (res.channels.Stable.downloads.chromedriver) |driver| {
            if (Utils.eql(u8, driver.platform, tag)) {
                chromeDriverURL = driver.url;
                break;
            }
        }
        var arrayList = try std.ArrayList([]const u8).initCapacity(self.getAllocator(), 100);
        defer arrayList.deinit(self.getAllocator());
        var t = std.mem.splitAny(u8, chromeDriverURL, "/");
        while (t.next()) |value| {
            try arrayList.append(self.getAllocator(), value);
        }
        const chromeDriverFileName = arrayList.items[arrayList.items.len - 1];
        if (chromeDriverFileName.len == 0 or Utils.eql(u8, chromeDriverFileName, "UNKNOWN")) {
            @panic("FileManager::downoadChromeDriverZip()::wrong osType exiting program...");
        }
        var req = Http.init(self.getAllocator(), self.logger);
        defer req.deinit();
        const headers = std.http.Client.Request.Headers{};
        const body = try req.makeRequest(
            chromeDriverURL,
            .GET,
            headers,
            null,
        );
        defer self.getAllocator().free(body);
        const file = try std.fs.cwd().createFile(
            chromeDriverFileName,
            .{ .read = true },
        );
        defer file.close();
        try file.writeAll(body);
        try file.seekTo(0);
        Utils.dirExists(Utils.getCWD(), "chromeDriver") catch |e| {
            try self.log(Types.LogLevels.ERROR, "FileManager::downoadChromeDriverZip()::chromeDriver folder does not exist creating folder: {s}", @errorName(e));
            try unZipChromeDriver(chromeDriverFileName);
        };
    }
    ///TODO:NEED TO FIX THIS BECAUSE OF ZIG 0.15.2 CHANGES
    fn unZipChromeDriver(fileName: []const u8) !void {
        const cwd = Utils.getCWD();
        const file = try cwd.openFile(fileName, .{});
        defer file.close();
        try cwd.makeDir("chromeDriver");
        var dir = try cwd.openDir("chromeDriver", .{ .iterate = true });
        defer dir.close();
        var readerBuff: [Utils.MAX_BUFF_SIZE * 8]u8 = undefined;
        var reader = file.reader(&readerBuff);
        var zipItter = try std.zip.Iterator.init(&reader);
        while (true) {
            const next = try zipItter.next();
            if (next) |entry| {
                if (entry.uncompressed_size == 0) continue;
                const totalOffSet = entry.filename_len + @sizeOf(std.zip.LocalFileHeader);
                try file.seekTo(@intCast(totalOffSet));
                var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
                _ = try entry.extract(&reader, .{}, &buf, dir);
            } else break;
        }
    }
    fn createStartDriverDetachedSh(self: *Self) !void {
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startDriverDetached));
        var startDriverDetachedShFile = try cwd.createFile(self.setShFileByOs(Actions.startDriverDetached), .{});
        try startDriverDetachedShFile.chmod(0o775);
        const fileData = try createStartDetachedShFileData(
            self.getAllocator(),
            chromeDriverSession,
            chromedriver,
            self.setShFileByOs(
                Actions.startChromeDriver,
            ),
        );
        defer self.getAllocator().free(fileData);
        Utils.writeAllToFile(startDriverDetachedShFile, fileData) catch |e| {
            @panic(@errorName(e));
        };
        startDriverDetachedShFile.close();
    }
    fn createDeleteDriverDetachedSh(self: *Self) !void {
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.deleteDriverDetached));
        var deleteDriverSessionDetachedShFile = try cwd.createFile(self.setShFileByOs(Actions.deleteDriverDetached), .{});
        defer deleteDriverSessionDetachedShFile.close();
        try deleteDriverSessionDetachedShFile.chmod(0o775);
        const fileData = try createDeleteDetachedShFileData(
            self.getAllocator(),
            chromeDriverSession,
            chromedriver,
        );
        defer self.getAllocator().free(fileData);
        Utils.writeAllToFile(deleteDriverSessionDetachedShFile, fileData) catch |e| {
            @panic(@errorName(e));
        };
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
        defer self.getAllocator().free(chromeDriverLogFilePath);
        try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startChromeDriver));
        var startChromeDriver = try cwd.createFile(self.setShFileByOs(Actions.startChromeDriver), .{});
        defer startChromeDriver.close();
        try startChromeDriver.chmod(0o775);
        var chromeDriverPathArray = try std.ArrayList([]const u8).initCapacity(
            self.getAllocator(),
            Utils.MAX_BUFF_SIZE,
        );
        defer chromeDriverPathArray.deinit(self.getAllocator());
        var splitChromePath = std.mem.splitSequence(u8, chromeDriverOptions.chromeDriverExecPath.?, "/");
        while (splitChromePath.next()) |next| {
            try chromeDriverPathArray.append(self.getAllocator(), next);
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
        const chromeDriverFolderPath = try std.mem.join(
            self.getAllocator(),
            "/",
            chromeDriverPathArray.items,
        );
        defer self.getAllocator().free(chromeDriverFolderPath);
        var buf4: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        const fileContents =
            \\#!/bin/bash
            \\cd "{s}"
            \\chmod +x ./{s}
            \\./{s} --port={d} --log-path={s} --headless &
            \\
        ;
        const formattedFileContents = try Utils.formatString(Utils.MAX_BUFF_SIZE, &buf4, fileContents, .{
            chromeDriverFolderPath,
            exeFileName,
            exeFileName,
            chromeDriverOptions.chromeDriverPort.?,
            chromeDriverLogFilePath,
        });
        _ = startChromeDriver.write(formattedFileContents) catch |e| {
            @panic(@errorName(e));
        };
    }
    fn createScreenShotDir(self: *Self) !void {
        const cwd = Utils.getCWD();
        Utils.dirExists(cwd, self.files.screenShotDir) catch |e| {
            try self.log(Types.LogLevels.ERROR, "FileManager::createScreenShotDir():{s}", @errorName(e));
            self.screenShotsDir = try Utils.openDir(cwd, self.files.screenShotDir);
        };
        const res = Utils.makeDirPath(cwd, self.files.screenShotDir);
        if (!res.Ok) {
            try self.log(Types.LogLevels.ERROR, "FileManager::createScreenShotDir()::err:{s}", res.Err);
            @panic("FileManager::createScreenShotDir()::cannot create directory, exiting program...");
        }
        self.screenShotsDir = try Utils.openDir(cwd, self.files.screenShotDir);
    }
    fn createStartDetachedShFileData(
        allocator: std.mem.Allocator,
        comptime sessionTitle: []const u8,
        comptime serviceName: []const u8,
        fileToRun: []const u8,
    ) ![]const u8 {
        // const outFileLog: []const u8 = "out";
        // const cleanUpFileName = if (fileToRun.len >= 10 and Utils.containsAtLeast(u8, fileToRun, 1, ".")) fileToRun[2 .. fileToRun.len - 3] else outFileLog;
        // const today = Utils.fromTimestamp(@intCast(time.timestamp()));
        // const max_len = 100;
        // var fileNameBuf: [max_len]u8 = undefined;
        // var fmtFileBuf: [max_len]u8 = undefined;
        // const outFilePipe = Utils.createFileName(
        //     max_len,
        //     &fileNameBuf,
        //     try Utils.formatString(max_len, &fmtFileBuf, "{s}_{d}_{d}_{d}", .{
        //         cleanUpFileName,
        //         today.year,
        //         today.month,
        //         today.day,
        //     }),
        //     Types.FileExtensions.LOG,
        // ) catch |e| {
        //     Utils.printLn("Utils::executeCmds()::err:{s}\n", .{@errorName(e)});
        //     @panic("Utils::executeCmds()::error creating fileName exiting program...\n");
        // };
        // const cwd = Utils.getCWD();
        // try Utils.deleteFileIfExists(cwd, outFilePipe);
        // const file = try cwd.createFile(outFilePipe, .{
        //     .read = false,
        //     .truncate = true,
        // });
        // try file.chmod(0o664);
        // file.close();
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
            \\echo "Starting a new scree session with $session_title"
            \\screen -dmS $session_title bash -c "chmod +x {s} && {s}; exec bash"
            \\
        ;
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        return try Utils.formatStringAndCopy(allocator, Utils.MAX_BUFF_SIZE, &buf, fileData, .{
            serviceName,
            serviceName,
            sessionTitle,
            fileToRun,
            fileToRun,
        });
    }
    fn createDeleteDetachedShFileData(
        allocator: std.mem.Allocator,
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
            \\
        ;
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        return try Utils.formatStringAndCopy(allocator, Utils.MAX_BUFF_SIZE, &buf, fileData, .{
            sessionTitle,
            serviceName,
            serviceName,
            "{print $1}",
        });
    }
    fn buildAndInstall(self: *Self, cwd: std.fs.Dir, folderNamePath: []const u8) !void {
        var formatBuf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        const pathToElectronFolder = try Utils.formatString(Utils.MAX_BUFF_SIZE, &formatBuf, "{s}/{s}/", .{
            folderNamePath,
            self.files.electronFolder,
        });
        try self.log(Types.LogLevels.INFO, "e2e path {s}:", folderNamePath);
        try self.log(Types.LogLevels.INFO, "electron folder path {s}:", pathToElectronFolder);
        // try self.log(Types.LogLevels.INFO, "dist folder path {s}:", pathToDistFolder);
        var buildAndInstallShFile = try cwd.createFile(self.setShFileByOs(Actions.buildAndInstallSh), .{});
        defer buildAndInstallShFile.close();
        try buildAndInstallShFile.chmod(0o775);
        const script =
            \\#!/bin/bash
            \\cd "{s}"
            \\echo "Run npm install..."
            \\npm install
            \\echo "Successfully installed running npm run build..."
            \\npm run build
            \\
        ;
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        const fileData = try Utils.formatStringAndCopy(
            self.getAllocator(),
            Utils.MAX_BUFF_SIZEformatString,
            &buf,
            comptime script,
            .{
                // pathToDistFolder,
                pathToElectronFolder,
            },
        );
        defer self.getAllocator().free(fileData);
        Utils.writeAllToFile(buildAndInstallShFile, fileData) catch |e| {
            try self.log(Types.LogLevels.ERROR, "FileManager::buildAndInstall()::received error: {s}", @errorName(e));
            @panic(@errorName(e));
        };
        self.executeFiles(self.setShFileByOs(Actions.buildAndInstallSh)) catch |er| {
            try self.log(Types.LogLevels.ERROR, "FileManager::buildAndInstall()::received error: {s}", @errorName(er));
            @panic(@errorName(er));
        };
    }
    //TODO: NOT SURE IF THIS IS NEEDED
    // fn handleFileDeletion(self: *Self) !void {
    //     const cwd = Utils.getCWD();
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startDriverDetached));
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.deleteDriverDetached));
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startExampleUISh));
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startUIDetached));
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.deleteExampleUiDetached));
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.deleteE2eDetached));
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startE2eSh));
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startE2eDetached));
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.buildAndInstallSh));
    //     try Utils.deleteFileIfExists(self.logger.logDir, self.files.driverOutFile);
    //     try cwd.deleteDir(self.screenShotsDir);
    //     try Utils.deleteFileIfExists(cwd, self.setShFileByOs(Actions.startChromeDriver));
    // }
    // fn handleFileCreation(_: *Self) !void {}
};
