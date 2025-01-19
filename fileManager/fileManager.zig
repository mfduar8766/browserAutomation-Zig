const std = @import("std");
const DriverTypes = @import("../driver/types.zig");
const builtIn = @import("builtin");
const Utils = @import("../lib/utils/utils.zig");
const Logger = @import("../lib/logger/logger.zig").Logger;
const Http = @import("../lib/http/http.zig").Http;
const Types = @import("../lib/types/types.zig");
const eql = std.mem.eql;

const ShFiles = struct {
    startChromeDriverSh: []const u8,
    startDriverDetachedSh: []const u8,
    deleteDriverDetachedSh: []const u8,
    startChromeDriverShW: []const u8,
    startDriverDetachedShW: []const u8,
    deleteDriverDetachedShW: []const u8,
};

fn createFileStructs() ShFiles {
    return ShFiles{
        .startChromeDriverSh = "./startChromeDriver.sh",
        .startDriverDetachedSh = "./startDriverDetached.sh",
        .deleteDriverDetachedSh = "./deleteDriverDetached.sh",
        .startChromeDriverShW = ".\\startChromeDriver.sh",
        .startDriverDetachedShW = ".\\startDriverDetached.sh",
        .deleteDriverDetachedShW = ".\\deleteDriverDetached.sh",
    };
}

pub const FileManager = struct {
    const Self = @This();
    arena: std.heap.ArenaAllocator = undefined,
    logger: Logger = undefined,
    driverOutFile: std.fs.File = undefined,
    shFiles: ShFiles = createFileStructs(),
    pub fn init(allocator: std.mem.Allocator, logger: Logger) FileManager {
        return FileManager{
            .logger = logger,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }
    pub fn deInit(self: *Self) void {
        self.arena.deinit();
        self.driverOutFile.close();
    }
    fn getAllocator(self: *Self) std.mem.Allocator {
        return self.arena.allocator();
    }
    pub fn createShFiles(self: *Self, chromeDriverOptions: DriverTypes.Options) !void {
        if (comptime builtIn.os.tag == .windows) {
            try self.createStartDriverDetachedSh(self.shFiles.startDriverDetachedShW);
            try self.deleteDriverDetachedSh(self.shFiles.deleteDriverDetachedShW);
            try self.createStartChromeDriverSh(self.shFiles.startChromeDriverSh, chromeDriverOptions);
        } else if (comptime builtIn.os.tag == .macos or builtIn.os.tag == .linux) {
            try self.createStartDriverDetachedSh(self.shFiles.startDriverDetachedSh);
            try self.deleteDriverDetachedSh(self.shFiles.deleteDriverDetachedSh);
            try self.createStartChromeDriverSh(self.shFiles.startChromeDriverSh, chromeDriverOptions);
        }
    }
    pub fn executeShFiles(self: *Self, fileName: []const u8) !void {
        if (comptime builtIn.os.tag == .windows) {
            const argv = [3][]const u8{
                "chmod",
                "+x",
                fileName,
            };
            var code = try Utils.executeCmds(3, self.getAllocator(), &argv);
            try Utils.checkExitCode(code.exitCode, "FileManager::executeShFiles()::cannot open chromeDriver, exiting program...");
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
            try Utils.checkExitCode(code.exitCode, "FileManager::executeShFiles()::cannot open chromeDriver, exiting program...");
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
            const dirverLogFileName: []const u8 = "driver.log";
            try Utils.deleteFileIfExists(self.logger.logDir, dirverLogFileName);
            self.driverOutFile = try self.logger.logDir.createFile(dirverLogFileName, .{ .truncate = true });
            const CWD_PATH = try Utils.getCWD().realpathAlloc(self.getAllocator(), ".");
            defer self.getAllocator().free(CWD_PATH);
            const logDirName = self.logger.logDirPath;
            var logDirPathBuf: [100]u8 = undefined;
            const formattedLogDirPath = try Utils.formatString(100, &logDirPathBuf, "/{s}/{s}", .{ logDirName, dirverLogFileName });
            chromeDriverLogFilePath = @as([]const u8, try Utils.concatStrings(self.getAllocator(), CWD_PATH, formattedLogDirPath));
        }
        return chromeDriverLogFilePath;
    }
    fn createStartChromeDriverSh(self: *Self, fileName: []const u8, chromeDriverOptions: DriverTypes.Options) !void {
        const cwd = Utils.getCWD();
        const chromeDriverLogFilePath = try self.createDriverOutDir(chromeDriverOptions.logFilePath);
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
        var buf1: [100]u8 = undefined;
        var buf2: [100]u8 = undefined;
        var buf3: [1024]u8 = undefined;
        const formattedDriverFolderPath = try Utils.formatString(100, &buf1, "cd \"{s}/\"\n", .{chromeDriverFolderPath});
        const formattedChmodX = try Utils.formatString(100, &buf2, "chmod +x ./{s}\n", .{chromeDriverExec});
        const formattedChromeDriverExeCall = try Utils.formatString(1024, &buf3, "./{s} --port={d} --log-path={s} &\n", .{
            chromeDriverExec,
            chromeDriverOptions.chromeDriverPort.?,
            chromeDriverLogFilePath,
        });

        var arrayList = try std.ArrayList(u8).initCapacity(self.getAllocator(), 1024);
        _ = try arrayList.writer().write("#!/bin/bash\n");
        _ = try arrayList.writer().write(formattedDriverFolderPath);
        _ = try arrayList.writer().write(formattedChmodX);
        _ = try arrayList.writer().write(formattedChromeDriverExeCall);
        var bufWriter = std.io.bufferedWriter(startChromeDriver.writer());
        const writer = bufWriter.writer();
        _ = try writer.print("{s}\n", .{arrayList.items});
        try bufWriter.flush();
        defer {
            self.getAllocator().free(chromeDriverLogFilePath);
            self.getAllocator().free(chromeDriverFolderPath);
            chromeDriverPathArray.deinit();
            startChromeDriver.close();
            arrayList.deinit();
        }
    }
};
