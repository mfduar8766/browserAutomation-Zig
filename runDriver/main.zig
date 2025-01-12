const std = @import("std");
const Utils = @import("lib").Utils;
const Logger = @import("lib").Logger;
const Config = @import("config");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    if (Config.chromeDriverExecPath.len == 0 or Config.chromeDriverPort.len == 0) {
        @panic("Main::main()::chromeDriverExecPath or chromeDriverPort args are empty, exiting function...");
    }

    const driverPort = try Utils.intToString(i32, Config.chromeDriverPort, null);
    const response = try Utils.checkIfPortInUse(allocator, driverPort);
    if (response.exitCode == 0) {
        @panic("Main::main()::port is already in use, exiting program...");
    }

    var logger = try Logger.init("Logs");
    try logger.info("Main::main()::creating startChromeDriver.sh script...", null);
    try logger.info("TEST", "FOO");

    const cwd = Utils.getCWD();
    const CWD_PATH = try cwd.realpathAlloc(allocator, ".");
    var logDirPathBuf: [100]u8 = undefined;
    const formattedLogDirPath = try Utils.formatString(100, &logDirPathBuf, "/{s}/driver.log", .{
        logger.logDirPath,
    });
    const chromeDriverLogFilePath = try Utils.concatStrings(allocator, CWD_PATH, formattedLogDirPath);

    var driverLogFileDir = try cwd.openDir("Logs", .{ .access_sub_paths = true, .iterate = true });
    var driverLogFileExists = true;
    // Utils.fileExists(cwd, "nohup.out") catch |e| switch (e) {
    //     error.FileNotFound => {
    //         try logger.warn("Main::main()::received error::", @errorName(e));
    //     },
    //     else => {
    //         try logger.info("Main::main():: file exists calling delete nohup.out", null);
    //         try cwd.deleteFile("nohup.out");
    //     },
    // };
    Utils.fileExists(driverLogFileDir, "driver.log") catch |e| switch (e) {
        error.FileNotFound => {
            try logger.warn("Main::main()::received error::", @errorName(e));
            driverLogFileExists = false;
        },
        else => {
            try logger.info("Main::main():: file exists calling delete driver.log", null);
        },
    };
    if (driverLogFileExists) {
        try driverLogFileDir.deleteFile("driver.log");
    }

    var driverLogFile = try driverLogFileDir.createFile("driver.log", .{ .truncate = false });
    const fileName = "startChromeDriver.sh";
    var fileExists = true;
    Utils.fileExists(cwd, fileName) catch |err| switch (err) {
        error.FileNotFound => {
            try logger.warn("Main::main()::startChromeDriver.sh file not found", @errorName(err));
            fileExists = false;
        },
        else => {
            try logger.info("Main::main()::startChromeDriver.sh file exists calling delete...", null);
        },
    };
    if (fileExists) {
        try cwd.deleteFile(fileName);
    }
    var arrayList = try std.ArrayList(u8).initCapacity(allocator, 1024);
    var startChromeDriver = try cwd.createFile(fileName, .{});
    try startChromeDriver.chmod(777);
    var chromeDriverPathArray = std.ArrayList([]const u8).init(allocator);
    var splitChromePath = std.mem.split(u8, Config.chromeDriverExecPath, "/");
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
    const formattedDriverFolderPath = try Utils.formatString(100, &buf1, "cd \"{s}/\"\n", .{joinedPath});
    const formattedChmodX = try Utils.formatString(100, &buf2, "chmod +x ./{s}\n", .{chromeDriverExec});
    const formattedPort = try Utils.formatString(1024, &buf3, "./{s} --port={d} --log-path={s} &\n", .{
        chromeDriverExec,
        driverPort,
        chromeDriverLogFilePath,
    });

    _ = try arrayList.writer().write("#!/bin/bash\n");
    _ = try arrayList.writer().write("cd ..\n");
    _ = try arrayList.writer().write(formattedDriverFolderPath);
    _ = try arrayList.writer().write(formattedChmodX);
    _ = try arrayList.writer().write(formattedPort);
    _ = try arrayList.writer().write("disown\n");
    var bufWriter = std.io.bufferedWriter(startChromeDriver.writer());
    const writer = bufWriter.writer();
    _ = try writer.print("{s}\n", .{arrayList.items});
    try bufWriter.flush();

    defer {
        logger.closeDirAndFiles();
        driverLogFileDir.close();
        driverLogFile.close();
        allocator.free(CWD_PATH);
        allocator.free(chromeDriverLogFilePath);
        allocator.free(joinedPath);
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

    // const runStart = struct {
    //     pub fn run(alloc: std.mem.Allocator) !void {
    //         const arg2 = [_][]const u8{
    //             "exec ./startChromeDriver.sh",
    //         };
    //         const code1 = try Utils.executeCmds(1, alloc, &arg2);
    //         try Utils.checkExitCode(code1.exitCode, "Utils::checkExitCode()::cannot open chromeDriver, exiting program...");
    //     }
    // };
    // const thread = try std.Thread.spawn(.{}, runStart.run, .{allocator});
    // thread.join();

    const arg2 = [_][]const u8{
        "./startChromeDriver.sh &",
    };
    code = try Utils.executeCmds(1, allocator, &arg2);
    try Utils.checkExitCode(code.exitCode, "Utils::checkExitCode()::cannot open chromeDriver, exiting program...");
    try logger.info("Main::main()::sleeping for 3 seconds waiting for driver to start....", null);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
