const std = @import("std");
const DriverTypes = @import("../driver/types.zig");
const builtIn = @import("builtin");
const Utils = @import("../lib/utils/utils.zig");
const Logger = @import("../lib/logger/logger.zig").Logger;
const Http = @import("../lib/http/http.zig").Http;
const Types = @import("../lib/types/types.zig");
const eql = std.mem.eql;
const time = std.time;

const Files = struct {
    startChromeDriverSh: []const u8,
    startDriverDetachedSh: []const u8,
    deleteDriverDetachedSh: []const u8,
    startChromeDriverShW: []const u8,
    startDriverDetachedShW: []const u8,
    deleteDriverDetachedShW: []const u8,
    loggerFileDir: []const u8,
    driverOutFile: []const u8,
    screenShotDir: []const u8,
};

fn createFileStructs() Files {
    return Files{
        .startChromeDriverSh = "./startChromeDriver.sh",
        .startDriverDetachedSh = "./startDriverDetached.sh",
        .deleteDriverDetachedSh = "./deleteDriverDetached.sh",
        .startChromeDriverShW = ".\\startChromeDriver.sh",
        .startDriverDetachedShW = ".\\startDriverDetached.sh",
        .deleteDriverDetachedShW = ".\\deleteDriverDetached.sh",
        .loggerFileDir = "Logs",
        .driverOutFile = "driver.log",
        .screenShotDir = "screenShots",
    };
}

pub const FileManager = struct {
    const Self = @This();
    arena: std.heap.ArenaAllocator = undefined,
    logger: Logger = undefined,
    driverOutFile: std.fs.File = undefined,
    files: Files = createFileStructs(),
    screenShotsDir: std.fs.Dir = undefined,
    pub fn init(allocator: std.mem.Allocator, logger: Logger) FileManager {
        return FileManager{
            .logger = logger,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }
    pub fn deInit(self: *Self) void {
        self.arena.deinit();
        self.driverOutFile.close();
        self.screenShotsDir.close();
    }
    fn getAllocator(self: *Self) std.mem.Allocator {
        return self.arena.allocator();
    }
    pub fn createFiles(self: *Self, chromeDriverOptions: DriverTypes.Options) !void {
        if (comptime builtIn.os.tag == .windows) {
            try self.createStartDriverDetachedSh(self.files.startDriverDetachedShW);
            try self.deleteDriverDetachedSh(self.files.deleteDriverDetachedShW);
            try self.createStartChromeDriverSh(self.files.startChromeDriverSh, chromeDriverOptions);
            try self.createScreenShotDir();
        } else if (comptime builtIn.os.tag == .macos or builtIn.os.tag == .linux) {
            try self.createStartDriverDetachedSh(self.files.startDriverDetachedSh);
            try self.deleteDriverDetachedSh(self.files.deleteDriverDetachedSh);
            try self.createStartChromeDriverSh(self.files.startChromeDriverSh, chromeDriverOptions);
            try self.createScreenShotDir();
        }
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
        var dest: [347828]u8 = undefined;
        try std.base64.standard.Decoder.decode(&dest, bytes);
        if (fileName) |name| {
            try Utils.deleteFileIfExists(self.screenShotsDir, name);
            const file = try self.screenShotsDir.createFile(name, .{});
            defer file.close();
            try file.writeAll(&dest);
        } else {
            var buf: [100]u8 = undefined;
            const today = Utils.fromTimestamp(@intCast(time.timestamp()));
            var buf2: [10]u8 = undefined;
            const timeStr = try Utils.formatString(10, &buf2, "{d}_{d}_{d}", .{
                today.year,
                today.month,
                today.day,
            });
            const name = try Utils.createFileName(
                100,
                &buf,
                "{s}{s}",
                timeStr,
                Types.FileExtensions.PNG,
            );
            try Utils.deleteFileIfExists(self.screenShotsDir, name);
            const file = try self.screenShotsDir.createFile(name, .{});
            defer file.close();
            try file.writeAll(&dest);
        }
    }
    fn downoadChromeDriverZip(self: *Self, res: Types.ChromeDriverResponse) !void {
        var chromeDriverURL: []const u8 = "";
        const tag = Utils.getOsType();
        if (tag.len == 0 or eql(u8, tag, "UNKNOWN")) {
            try self.logger.fatal("FileManager::downoadChromeDriverZip()::cannot find OSType", tag);
            @panic("FileManager::downoadChromeDriverZip()::osType does not exist exiting program...");
        }
        for (res.channels.Stable.downloads.chromedriver) |driver| {
            if (eql(u8, driver.platform, tag)) {
                chromeDriverURL = driver.url;
                break;
            }
        }
        var arrayList = try std.ArrayList([]const u8).initCapacity(self.getAllocator(), 100);
        defer arrayList.deinit();
        var t = std.mem.split(u8, chromeDriverURL, "/");
        while (t.next()) |value| {
            try arrayList.append(value);
        }
        const chromeDriverFileName = arrayList.items[arrayList.items.len - 1];
        if (chromeDriverFileName.len == 0 or eql(u8, chromeDriverFileName, "UNKNOWN")) {
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
    fn createStartDriverDetachedSh(_: *Self, fileName: []const u8) !void {
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, fileName);
        var startDriverDetachedSh = try cwd.createFile(fileName, .{});
        try startDriverDetachedSh.chmod(777);
        const fileData: []const u8 =
            \\#!/bin/bash
            \\# Define the screen session title
            \\session_title="chromeDriverSession"
            \\# Kill existing session with same title if it exists
            \\if screen -ls | grep -q "$session_title"; then
            \\  echo "screen $session_title is running, restarting session"
            \\  screen -S $session_title -X quit
            \\fi
            \\# Start a new screen session with the title 'web_server' and run the command to start the server
            \\screen -dmS $session_title bash -c "chmod +x ./startChromeDriver.sh && ./startChromeDriver.sh; exec bash"
        ;
        _ = try startDriverDetachedSh.writeAll(fileData);
        defer startDriverDetachedSh.close();
    }
    fn deleteDriverDetachedSh(_: *Self, fileName: []const u8) !void {
        const cwd = Utils.getCWD();
        try Utils.deleteFileIfExists(cwd, fileName);
        var deleteDriverSessionDetachedSh = try cwd.createFile(fileName, .{});
        try deleteDriverSessionDetachedSh.chmod(777);
        const f: []const u8 =
            \\#!/bin/bash
            \\# Define the title you're looking for
            \\session_title="chromeDriverSession"
            \\# Get the session ID by matching the title
            \\session_id=$(screen -ls | grep "$session_title" | awk '{print $1}' | cut -d'.' -f1)
            \\# Check if the session was found
            \\if [ -n "$session_id" ]; then
            \\  echo "Killing screen session: $session_id"
            \\  # Kill the screen session
            \\  screen -S "$session_id" -X quit
            \\else
            \\ echo "No screen session found with title: $session_title"
            \\fi
        ;
        _ = try deleteDriverSessionDetachedSh.writeAll(f);
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
    fn createStartChromeDriverSh(self: *Self, fileName: []const u8, chromeDriverOptions: DriverTypes.Options) !void {
        const cwd = Utils.getCWD();
        const chromeDriverLogFilePath = try self.createDriverOutDir(chromeDriverOptions.chromeDriverOutFilePath);
        try Utils.deleteFileIfExists(cwd, fileName);
        var startChromeDriver = try cwd.createFile(fileName, .{});
        try startChromeDriver.chmod(777);
        var chromeDriverPathArray = try std.ArrayList([]const u8).initCapacity(self.getAllocator(), 1024);
        var splitChromePath = std.mem.splitSequence(u8, chromeDriverOptions.chromeDriverExecPath.?, "/");

        while (splitChromePath.next()) |next| {
            try chromeDriverPathArray.append(next);
        }
        const index = Utils.indexOf([][]const u8, chromeDriverPathArray.items, []const u8, "chromeDriver");
        if (index == -1) {
            @panic("FileManager::createStartChromeDriverSh()::cannot find chromeDriver folder, exiting program...");
        }

        const chromeDriverExec = chromeDriverPathArray.pop();
        const chromeDriverExecFolderIndex = chromeDriverPathArray.items[@as(usize, @intCast(index))..];
        const chromeDriverFolderPath = try std.mem.join(self.getAllocator(), "/", chromeDriverExecFolderIndex);
        var buf4: [1024]u8 = undefined;
        const fileContents =
            \\#!/bin/bash
            \\cd "{s}"
            \\chmod +x ./{s}
            \\./{s} --port={d} --log-path={s} &
        ;
        const formattedFileContents = try Utils.formatString(1024, &buf4, fileContents, .{
            chromeDriverFolderPath,
            chromeDriverExec,
            chromeDriverExec,
            chromeDriverOptions.chromeDriverPort.?,
            chromeDriverLogFilePath,
        });
        _ = try startChromeDriver.write(formattedFileContents);
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
};
