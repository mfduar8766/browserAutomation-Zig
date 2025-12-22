const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const time = std.time;
const Allocator = std.mem.Allocator;
const Types = @import("../types/types.zig");
const process = std.process;
const print = std.debug.print;
const builtIn = @import("builtin");
const posix = std.posix;

pub const Errors = error{
    FileNotFound,
    EmptyFile,
    InputOutput,
    AccessDenied,
    BrokenPipe,
    SystemResources,
    OperationAborted,
    LockViolation,
    WouldBlock,
    ConnectionResetByPeer,
    ProcessNotFound,
    Unexpected,
    IsDir,
    ConnectionTimedOut,
    NotOpenForReading,
    SocketNotConnected,
    Canceled,
    StreamTooLong,
    EnvironmentVariableNotFound,
    SegmentationFault,
    OutOfMemory,
    WriteFailed,
    PermissionDenied,
    Unseekable,
    SharingViolation,
    PathAlreadyExists,
    PipeBusy,
    NoDevice,
    NameTooLong,
    InvalidUtf8,
    InvalidWtf8,
    BadPathName,
    NetworkNotFound,
    AntivirusInterference,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    FileTooBig,
    NoSpaceLeft,
    NotDir,
    DeviceBusy,
    FileLocksNotSupported,
    FileBusy,
    DiskQuota,
    InvalidArgument,
    NotOpenForWriting,
    MessageTooBig,
    ReadOnlyFileSystem,
    FileSystem,
    CurrentWorkingDirectoryUnlinked,
    InvalidBatchScriptArg,
    InvalidExe,
    ResourceLimitReached,
    InvalidUserId,
    ProcessAlreadyExec,
    InvalidProcessGroupId,
    InvalidName,
    InvalidHandle,
    WaitAbandoned,
    WaitTimeOut,
};

pub const MAX_BUFF_SIZE = 1024;

pub const ExecCmdResponse = struct {
    exitCode: i32 = 0,
    message: []const u8 = "",
};

pub const DateTime = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    millisecond: u16,
};

pub fn fromTimestamp(ts: u64) DateTime {
    const SECONDS_PER_DAY = 86400;
    const DAYS_PER_YEAR = 365;
    const DAYS_IN_4YEARS = 1461;
    const DAYS_IN_100YEARS = 36524;
    const DAYS_IN_400YEARS = 146097;
    const DAYS_BEFORE_EPOCH = 719468;
    const MILLISECONDS_PER_SECOND: u64 = 1000;

    // --- Millisecond Calculation (Step 1) ---
    // The remainder of the total timestamp divided by 1000 is the millisecond part.
    const millisecond: u16 = @intCast(@rem(ts, MILLISECONDS_PER_SECOND));

    const seconds_since_midnight: u64 = @rem(ts, SECONDS_PER_DAY);
    var day_n: u64 = DAYS_BEFORE_EPOCH + ts / SECONDS_PER_DAY;
    var temp: u64 = 0;

    temp = 4 * (day_n + DAYS_IN_100YEARS + 1) / DAYS_IN_400YEARS - 1;
    var year: u16 = @intCast(100 * temp);
    day_n -= DAYS_IN_100YEARS * temp + temp / 4;

    temp = 4 * (day_n + DAYS_PER_YEAR + 1) / DAYS_IN_4YEARS - 1;
    year += @intCast(temp);
    day_n -= DAYS_PER_YEAR * temp + temp / 4;

    var month: u8 = @intCast((5 * day_n + 2) / 153);
    const day: u8 = @intCast(day_n - (@as(u64, @intCast(month)) * 153 + 2) / 5 + 1);

    month += 3;
    if (month > 12) {
        month -= 12;
        year += 1;
    }

    return DateTime{
        .year = year,
        .month = month,
        .day = day,
        .hour = @intCast(seconds_since_midnight / 3600),
        .minute = @intCast(seconds_since_midnight % 3600 / 60),
        .second = @intCast(seconds_since_midnight % 60),
        .millisecond = millisecond,
    };
}

pub fn toRFC3339(bufLen: comptime_int, buf: *[bufLen]u8, dt: DateTime) ![]const u8 {
    return try formatString(bufLen, buf, comptime "{d}-{d}-{d}T{d}:{d}:{d}:{d}Z", .{
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
        dt.millisecond,
    });
}

fn paddingTwoDigits(buf: *[2]u8, value: u8) void {
    switch (value) {
        0 => buf.* = "00".*,
        1 => buf.* = "01".*,
        2 => buf.* = "02".*,
        3 => buf.* = "03".*,
        4 => buf.* = "04".*,
        5 => buf.* = "05".*,
        6 => buf.* = "06".*,
        7 => buf.* = "07".*,
        8 => buf.* = "08".*,
        9 => buf.* = "09".*,
        // todo: optionally can do all the way to 59 if you want
        else => _ = std.fmt.formatIntBuf(buf, value, 10, .lower, .{}),
    }
}

pub const Result = struct {
    Ok: bool = false,
    Err: [:0]const u8 = "",
};

pub fn type_or_void(comptime c: bool, comptime t: type) type {
    if (c) {
        return t;
    } else {
        return void;
    }
}

pub fn value_or_void(comptime c: bool, v: anytype) type_or_void(c, @TypeOf(v)) {
    if (c) {
        return v;
    } else {
        return {};
    }
}

pub fn getCWD() fs.Dir {
    return fs.cwd();
}

/// Calls os.makePath
/// Calls makeDir iteratively to make an entire path (i.e. creating any parent directories that do not exist).
/// Returns success if the path already exists and is a directory.
/// This function is not atomic, and if it returns an error, the file system may have been modified regardless.
/// On Windows, sub_path should be encoded as WTF-8. On WASI, sub_path should be encoded as valid UTF-8.
/// On other platforms, sub_path is an opaque sequence of bytes with no particular encoding.
pub fn makeDirPath(cwd: std.fs.Dir, dirPath: []const u8) Result {
    cwd.makePath(dirPath) catch |e| {
        std.debug.print("Utils::FileOrDirExists()::error: {}\n", .{e});
        return createErrorStruct(false, e);
    };
    return Result{ .Err = "", .Ok = true };
}

/// Does a recursive check to see if the given file exists in the dir
pub fn fileExistsInDir(dir: fs.Dir, fileName: []const u8) !bool {
    var itter = dir.iterate();
    var exists = false;
    while (try itter.next()) |entry| {
        if (eql(u8, entry.name, ".") or eql(u8, entry.name, "..")) continue;
        switch (entry.kind) {
            .file => {
                if (eql(u8, entry.name, fileName)) {
                    exists = true;
                    break;
                }
            },
            .directory => {
                var sub_dir = try dir.openDir(entry.name, .{ .iterate = true, .access_sub_paths = true });
                defer sub_dir.close();
                exists = try fileExists(sub_dir, fileName);
            },
            else => {},
        }
    }
    return exists;
}

pub fn createFileName(bufLen: comptime_int, buf: *[bufLen]u8, args: anytype, extension: Types.FileExtensions) ![]const u8 {
    return switch (extension) {
        .TXT => try formatString(bufLen, buf, "{s}.{s}", .{ args, Types.FileExtensions.get(0) }),
        .PNG => try formatString(bufLen, buf, "{s}.{s}", .{ args, Types.FileExtensions.get(1) }),
        .JPG => try formatString(bufLen, buf, "{s}.{s}", .{ args, Types.FileExtensions.get(2) }),
        .LOG => try formatString(bufLen, buf, "{s}.{s}", .{ args, Types.FileExtensions.get(3) }),
        .SH => try formatString(bufLen, buf, "{s}.{s}", .{ args, Types.FileExtensions.get(4) }),
    };
}

fn createErrorStruct(value: bool, err: ?anyerror) Result {
    var res: Result = .{ .Ok = value };
    if (err) |e| {
        res.Err = @errorName(e);
        std.debug.print("Utils::createErrorStruct()::{s}\n", .{@errorName(e)});
    }
    return res;
}

pub fn createDir(dir: []const u8) Result {
    const cwd = getCWD();
    var res: Result = .{};
    cwd.makeDir(dir) catch |e| {
        return createErrorStruct(false, e);
    };
    res.Ok = true;
    return res;
}

pub fn createFile(cwd: std.fs.Dir, dirName: []const u8, fileName: []const u8, mode: ?comptime_int) !struct {
    file: std.fs.File,
    dir: std.fs.Dir,
} {
    var dir = try cwd.openDir(dirName, .{ .access_sub_paths = true, .iterate = true });
    comptime var modeType: comptime_int = std.fs.Dir.default_mode;
    if (mode) |m| {
        modeType = m;
    }
    const file = try dir.createFile(fileName, .{
        .truncate = false,
        .mode = modeType,
    });
    return .{
        .file = file,
        .dir = dir,
    };
}

pub fn concatStrings(allocator: Allocator, a: []const u8, b: []const u8) ![]u8 {
    var bytes = try allocator.alloc(u8, a.len + b.len);
    std.mem.copyForwards(u8, bytes, a);
    std.mem.copyForwards(u8, bytes[a.len..], b);
    return bytes;
}

pub fn openDir(dir: std.fs.Dir, dirName: []const u8) !fs.Dir {
    return try dir.makeOpenPath(dirName, .{ .access_sub_paths = true, .iterate = true });
}

pub fn readCmdArgs(comptime T: type, allocator: Allocator, args: *std.process.ArgIterator) !std.json.Parsed(T) {
    var optionsFile: []const u8 = "";
    while (args.next()) |a| {
        var splitArgs = std.mem.splitAny(u8, a, "=");
        while (splitArgs.next()) |next| {
            if (std.mem.endsWith(u8, next, ".json")) {
                optionsFile = next;
                break;
            }
        }
    }
    if (optionsFile.len == 0) {
        @panic("Utils::readCmdArgs()::no options.json file passed in, exiting program...");
    }
    const cwd = getCWD();
    var buf: [2000]u8 = undefined;
    const content = try cwd.readFile(optionsFile, &buf);
    if (content.len == 0) {
        @panic("Utils::readCmdArgs()::options.json file is empty, exiting program...");
    }
    return try std.json.parseFromSlice(T, allocator, content, .{ .ignore_unknown_fields = true });
}

pub fn fileExists(cwd: std.fs.Dir, fileName: []const u8) std.fs.Dir.AccessError!void {
    return try cwd.access(fileName, .{});
}

pub fn fileExistsBool(cwd: std.fs.Dir, fileName: []const u8) bool {
    cwd.access(fileName, .{}) catch |e| {
        if (e == Errors.PathAlreadyExists) {
            return true;
        } else {
            printLn("Utils::fileExistsBool()::received error: {s}", @errorName(e));
            return false;
        }
    };
    return true;
}

// TODO: come back to this
pub fn parseJSON(comptime T: type, allocator: Allocator, body: []const u8, options: std.json.ParseOptions) !std.json.Parsed(T) {
    return try std.json.parseFromSlice(T, allocator, body, options);
}

pub fn stringify(allocator: Allocator, value: anytype, options: std.json.Stringify.Options) ![]u8 {
    var out = std.io.Writer.Allocating.init(allocator);
    const writter = &out.writer;
    defer out.deinit();
    try std.json.Stringify.value(value, options, writter);
    const bytes = try allocator.alloc(u8, out.written().len);
    std.mem.copyForwards(u8, bytes, out.written());
    return bytes;
}

pub fn dirExists(cwd: std.fs.Dir, dirName: []const u8) std.fs.Dir.AccessError!void {
    return cwd.access(dirName, .{});
}

pub fn dirExistsBool(cwd: std.fs.Dir, dirName: []const u8) bool {
    cwd.access(dirName, .{}) catch |e| {
        if (e == Errors.PathAlreadyExists) {
            return true;
        } else {
            printLn("Utils::dirExistsBool()::received error: {s}", @errorName(e));
            return false;
        }
    };
    return true;
}

pub fn makePath(dir: std.fs.Dir, dirName: []const u8) (std.fs.Dir.MakeError || std.fs.Dir.StatFileError)!void {
    return try dir.makePath(dirName);
}

pub fn indexOf(comptime T: type, slice: T, comptime T2: type, value: T2) isize {
    var index: isize = -1;
    for (slice, 0..) |el, i| {
        const element = @as(@Type(@typeInfo(T2)), el);
        if (eql(u8, element, value)) {
            index = @as(isize, @intCast(i));
            break;
        }
    }
    return index;
}

pub fn writeToStdOut(logDir: fs.Dir, outFile: []const u8) !void {
    var buf: [MAX_BUFF_SIZE]u8 = undefined;
    const data = try logDir.readFile(outFile, &buf);
    const outw = std.io.getStdOut().writer();
    try outw.print("{s}\n", .{data});
}

pub fn checkForNullPrtDeref(value: anytype) !void {
    if (@intFromPtr(value.ptr) == 0) {
        // Since the pointer is 0x0, it's a null pointer dereference waiting to happen.
        // We handle this gracefully now.
        return error.SegmentationFault;
    }
}

pub fn executeCmds(
    argsLen: comptime_int,
    allocator: Allocator,
    args: *const [argsLen][]const u8,
    incomingFileName: []const u8,
) !ExecCmdResponse {
    var execResponse = ExecCmdResponse{};
    const outFileLog: []const u8 = "out";
    const cleanUpFileName = if (incomingFileName.len >= 10 and containsAtLeast(u8, incomingFileName, 1, ".")) incomingFileName[2 .. incomingFileName.len - 3] else outFileLog;
    const argv_slice = &args.*;
    const fullCommand = try join(allocator, " ", argv_slice);
    defer allocator.free(fullCommand);
    printLn("Utils::executeCmds()::argsLen: {d}, incomingFileName: {s}, cleanUpFileName: {s}, fullCommand: {s}", .{
        argsLen,
        incomingFileName,
        cleanUpFileName,
        fullCommand,
    });
    var child: std.process.Child = undefined;
    if (containsAtLeast(u8, fullCommand, 1, "chmod +x")) {
        printLn("Utils::executeCmds()::running chmod +x", .{});
        child = std.process.Child.init(args, allocator);
    } else {
        const today = fromTimestamp(@intCast(time.timestamp()));
        const max_len = 100;
        var buf: [max_len]u8 = undefined;
        var fmtFileBuf: [max_len]u8 = undefined;
        const fileName = createFileName(
            max_len,
            &buf,
            try formatString(max_len, &fmtFileBuf, "{s}_{d}_{d}_{d}", .{
                cleanUpFileName,
                today.year,
                today.month,
                today.day,
            }),
            Types.FileExtensions.LOG,
        ) catch |e| {
            printLn("Utils::executeCmds()::err:{s}\n", .{@errorName(e)});
            @panic("Utils::executeCmds()::error creating fileName exiting program...\n");
        };
        try deleteFileIfExists(getCWD(), fileName);
        const file = try getCWD().createFile(fileName, .{
            .read = false,
            .truncate = true,
        });
        try file.chmod(0o664); // 0o664 (rw-rw-r--) is safer than 777
        file.close();
        var commandStrBuf: [100]u8 = undefined;
        const command_str = try formatStringAndCopy(allocator, 100, &commandStrBuf, "{s} > {s} 2>&1", .{ fullCommand, fileName });
        defer allocator.free(command_str);
        const innerCmd = command_str;
        var cmdBuf: [200]u8 = undefined;
        const cmd = try std.fmt.bufPrint(&cmdBuf, "{s}", .{innerCmd});
        std.debug.print("Utils::executeCmds()::running command:{s}\n", .{cmd});
        child = std.process.Child.init(
            &[_][]const u8{
                "/bin/bash",
                "-c",
                cmd,
            },
            allocator,
        );
    }
    try child.spawn();
    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                printLn("Utils::executeCmds()::The following command exited with error code: {d}", .{code});
                execResponse.exitCode = @as(i32, @intCast(code));
                execResponse.message = @errorName(error.CommandFailed);
                return execResponse;
            }
        },
        .Signal => |sig| {
            printLn("Utils::executeCmds()::The following command returned signal: {any}", .{sig});
            execResponse.exitCode = @as(i32, @intCast(sig));
            execResponse.message = @errorName(error.Signal);
            return execResponse;
        },
        .Unknown => |u| {
            std.debug.print("Utils::executeCmds()::The following command returned signal: {any}\n", .{u});
            execResponse.exitCode = @as(i32, @intCast(u));
            execResponse.message = "Unknown";
            return execResponse;
        },
        .Stopped => |s| {
            printLn("Utils::executeCmds()::The following command returned signal: {any}", .{s});
            execResponse.exitCode = @as(i32, @intCast(s));
            execResponse.message = "Stopped";
            return execResponse;
        },
    }
    return execResponse;
}

pub fn binarySearch(comptime T: type, slice: T, element: anytype) i32 {
    if (@TypeOf(element) != @Type(@typeInfo(T))) {
        print("Utils::binarySearch():: element must be same as the T type in the list.", .{});
        return -1;
    }
    var left: usize = 0;
    var right: usize = slice.len - 1;
    while (left <= right) {
        var mid = left + (right - left) / 2;
        if (slice[mid] == element) {
            return @as(i32, @intCast(mid));
        } else if (slice[mid] < element) {
            mid = mid + 1;
            left = mid;
        } else {
            mid = mid - 1;
            right = mid;
        }
    }
    return -1;
}

pub fn checkExitCode(code: i32, message: []const u8) !void {
    if (code != 0) {
        std.debug.print("Utils::checkExitCode()::received errorCode: {d} message: {s}\n", .{ code, message });
        @panic(message);
    }
}

pub fn printLn(comptime message: []const u8, args: anytype) void {
    const newMessage = message ++ "\n";
    if (@typeInfo(@TypeOf(args)) == .@"struct") {
        print(newMessage, args);
    } else {
        print(newMessage, .{args});
    }
}

pub fn formatString(bufLen: comptime_int, buf: *[bufLen]u8, comptime fmt: []const u8, args: anytype) ![]const u8 {
    return @as([]const u8, try std.fmt.bufPrint(buf, fmt, args));
}

pub fn formatStringAndCopy(allocator: Allocator, bufLen: comptime_int, buf: *[bufLen]u8, comptime fmt: []const u8, args: anytype) ![]const u8 {
    const formatted_slice = try std.fmt.bufPrint(buf, fmt, args);
    // 2. Use the allocator to duplicate (copy) the string slice onto the heap
    // The new slice returned here is stable and owned by the allocator.
    return try copyString(allocator, formatted_slice);
}

pub fn copyString(allocator: Allocator, slice: []const u8) ![]const u8 {
    return allocator.dupe(u8, slice);
}

pub fn stringFmt(buf: *[MAX_BUFF_SIZE]u8, args: anytype) ![]const u8 {
    return @as([]const u8, try std.fmt.bufPrint(buf, "{s}", args));
}

pub fn intToStringFmt(buf: *[32]u8, args: anytype) ![]const u8 {
    return @as([]const u8, try std.fmt.bufPrint(buf, "{d}", args));
}

pub fn assert(value: bool) void {
    return std.mem.assert(value);
}

pub fn intToString(T: type, buf: []const u8, base: ?u8) !T {
    var defaultBase: u8 = 10;
    if (base) |b| {
        defaultBase = b;
    }
    return try std.fmt.parseInt(T, buf, defaultBase);
}

// TODO: Fix this later
pub fn getPID(allocator: Allocator, bufLen: comptime_int, buf: *[bufLen]u8, processName: []const u8) !ExecCmdResponse {
    const query = try std.fmt.bufPrint(buf, "{s}", .{processName});
    print("F: {s}\n", .{query});
    const args = [_][]const u8{
        "ps acux",
    };
    // ps acux| grep Terminal
    // args: *const [argsLen][]const u8
    const response = try executeCmds(1, allocator, &args);
    return response;
}

/// if port is in use lsof -i:PORT returns 0 else 1
pub fn checkIfPortInUse(allocator: Allocator, port: ?i32, browser: ?[]const u8) !ExecCmdResponse {
    var execResponse = ExecCmdResponse{ .exitCode = 1, .message = "port is free" };
    var child: std.process.Child = undefined;
    if (browser) |b| {
        const args = [_][]const u8{ "lsof", "-i", "-c", b };
        printLn("Utils::checkIfPortInUse()::checking if browser: {s} is available", .{b});
        child = std.process.Child.init(&args, allocator);
    }
    if (port) |p| {
        var buf: [16]u8 = undefined;
        const formattedPort = try std.fmt.bufPrint(&buf, ":{d}", .{p});
        const args = [_][]const u8{
            "lsof",
            "-i",
            formattedPort,
        };
        printLn("Utils::checkIfPortInUse()::checking if port: {d} is in use", p);
        child = std.process.Child.init(&args, allocator);
    }
    try child.spawn();
    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code != 1) {
                printLn("Utils::checkIfPortInUse()::The following command exited with error code: {d}", .{code});
                execResponse.exitCode = @as(i32, @intCast(code));
                execResponse.message = if (code == 0) "port is use" else "port is free";
                return execResponse;
            }
        },
        .Signal => |sig| {
            printLn("Utils::checkIfPortInUse()::The following command returned signal: {any}", .{sig});
            execResponse.exitCode = @as(i32, @intCast(sig));
            execResponse.message = @errorName(error.Signal);
            return execResponse;
        },
        .Unknown => |u| {
            std.debug.print("Utils::checkIfPortInUse()::The following command returned signal: {any}\n", .{u});
            execResponse.exitCode = @as(i32, @intCast(u));
            execResponse.message = "Unknown";
            return execResponse;
        },
        .Stopped => |s| {
            printLn("Utils::executeCmds()::The following command returned signal: {any}", .{s});
            execResponse.exitCode = @as(i32, @intCast(s));
            execResponse.message = "Stopped";
            return execResponse;
        },
    }
    return execResponse;
}

pub fn deleteFileIfExists(cwd: std.fs.Dir, fileName: []const u8) !void {
    var exists = true;
    fileExists(cwd, fileName) catch |e| {
        printLn("Utils::deleteFileIfExists()::error:: {s}", @errorName(e));
        switch (e) {
            error.FileNotFound => {
                exists = false;
                printLn("Utils::deleteFileIfExists()::error: {s}, fileName:{s}", .{ @errorName(e), fileName });
            },
            else => {
                printLn("Utils::deleteFileIfExists()::exists, deleting file: {s} and re creating it", fileName);
            },
        }
    };
    if (exists) {
        try cwd.deleteFile(fileName);
    }
}

pub fn getOsType() []const u8 {
    return switch (comptime builtIn.os.tag) {
        .macos => {
            if (builtIn.cpu.arch.isX86()) {
                return Types.PlatForms.getOS(2);
            }
            return Types.PlatForms.getOS(1);
        },
        .windows => {
            if (builtIn.cpu.arch.isX86()) {
                return Types.PlatForms.getOS(4);
            }
            return Types.PlatForms.getOS(3);
        },
        .linux => Types.PlatForms.getOS(0),
        else => "",
    };
}

pub fn convertToString(
    bufLen: comptime_int,
    buf: *[bufLen]u8,
    TData: type,
    data: anytype,
    comptime message: []const u8,
) !struct { data: ?[]const u8, message: []const u8 } {
    const typeInfo = @typeInfo(TData);
    if (typeInfo != .null) {
        if (typeInfo == .@"struct") {
            const formattedMessage = try std.fmt.bufPrint(buf, message, data);
            return .{ .message = @as([]const u8, formattedMessage), .data = null };
        } else if (typeInfo == .comptime_int or typeInfo == .comptime_float or typeInfo == .int or typeInfo == .float or TData == usize) {
            const formattedMessage = try std.fmt.bufPrint(buf, message, .{data});
            return .{ .message = @as([]const u8, formattedMessage), .data = null };
        } else if (typeInfo == .pointer) {
            const isConst = typeInfo.pointer.is_const;
            const child = typeInfo.pointer.child;
            if (isConst and (child == u8 or child == [data.len:0]u8 or TData == *const [data.len:0]u8 or TData == []const u8)) {
                const formattedMessage = try std.fmt.bufPrint(buf, message, .{data});
                return .{ .message = @as([]const u8, formattedMessage), .data = null };
            }
        }
    }
    return .{ .data = null, .message = message };
}

pub fn startsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
    return std.mem.startsWith(T, haystack, needle);
}

///Returns true if and only if the slices have the same length and all elements compare true using equality operator.
pub fn eql(comptime T: type, a: []const T, b: []const T) bool {
    return std.mem.eql(T, a, b);
}

pub fn endsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
    return std.mem.endsWith(T, haystack, needle);
}

pub fn containsAtLeast(comptime T: type, haystack: []const T, expected_count: usize, needle: []const T) bool {
    return std.mem.containsAtLeast(
        T,
        haystack,
        expected_count,
        needle,
    );
}

/// sleep() - Takes a duration in milliseconds
pub fn sleep(durrationMs: u64) void {
    const multiplier = @as(u64, @intFromFloat(1e6));
    const duration = durrationMs * multiplier;
    // time.sleep(duration);
    std.Thread.sleep(duration);
}

pub fn join(allocator: Allocator, separator: []const u8, slices: []const []const u8) Allocator.Error![]u8 {
    return try std.mem.join(allocator, separator, slices);
}

///Splits the string at a delimiter and appends to the end of the string if append value is passed in
pub fn splitAndJoinStr(
    allocator: Allocator,
    string: []const u8,
    delimiters: []const u8,
    append: ?[]const u8,
) ![][]const u8 {
    var arrayList = std.ArrayList([]const u8).empty;
    var itter = std.mem.splitAny(u8, string, delimiters);
    while (itter.next()) |value| {
        try arrayList.append(allocator, value);
    }
    if (append) |app| {
        try arrayList.append(allocator, app);
    }
    return try arrayList.toOwnedSlice(allocator);
}

pub fn getEnvValueByKey(allocator: Allocator, key: []const u8) ![]const u8 {
    const cwd = getCWD();
    const fileName: []const u8 = ".env";
    const CWD_PATH = @as([]const u8, try cwd.realpathAlloc(allocator, "../"));
    defer allocator.free(CWD_PATH);
    const split = try splitAndJoinStr(allocator, CWD_PATH, "/", fileName);
    const file_path = try join(allocator, "/", split);
    defer allocator.free(split);
    defer allocator.free(file_path);

    fileExists(cwd, file_path) catch |e| {
        printLn("Utils::getEnvVar()::env file does not exist {any} checking for env vars on system", e);
        if (e == Errors.FileNotFound) {
            return try std.process.getEnvVarOwned(allocator, key);
        }
    };
    const file = cwd.openFile(file_path, .{ .mode = .read_only }) catch |er| {
        printLn("Utils::getEnvVar()::received error {any} trying to open file", er);
        return er;
    };
    defer file.close();

    const fileStat = file.stat() catch |er| {
        printLn("Utils::getEnvVar()::received error: {}", er);
        return er;
    };
    if (fileStat.size == 0) {
        return Errors.EmptyFile;
    }
    const file_size = @as(usize, @intCast(fileStat.size));
    const fileAllocBuff = try allocator.alloc(u8, file_size);
    errdefer allocator.free(fileAllocBuff);

    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var value: []const u8 = "";
    var envValueBytes: []u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&fileAllocBuff, '\n')) |line| {
        if (startsWith(u8, @as([]const u8, line), key)) {
            const envValue = try splitAndJoinStr(
                allocator,
                @as([]const u8, line),
                "=",
                undefined,
            );
            defer allocator.free(envValue);
            if (envValue.len > 0) {
                value = envValue[1];
                envValueBytes = try allocator.alloc(u8, value.len);
                std.mem.copyForwards(u8, envValueBytes, value);
                break;
            }
        }
    }
    return envValueBytes;
}

pub fn readAndParseFile(
    T: type,
    allocator: Allocator,
    cwd: fs.Dir,
    fileName: []const u8,
) !std.json.Parsed(T) {
    const file = try cwd.openFile(fileName, .{ .mode = .read_only });
    defer file.close();
    const file_stat = try file.stat();
    const file_size = @as(usize, @intCast(file_stat.size));
    const fileAllocBuff = try allocator.alloc(u8, file_size);
    errdefer allocator.free(fileAllocBuff);
    const bytes_read = try file.readAll(fileAllocBuff);
    if (bytes_read != file_size) {
        return error.IncompleteFileRead;
    }
    defer allocator.free(fileAllocBuff);
    return try parseJSON(T, allocator, fileAllocBuff, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
}

pub fn isNullOrUndefined(T: type) bool {
    const typeInfo = @typeInfo(T);
    if (typeInfo == .null or typeInfo == .undefined) {
        return true;
    } else {
        return false;
    }
}

pub fn writeAllToFile(file: fs.File, data: []const u8) !void {
    var buff: [MAX_BUFF_SIZE * 8]u8 = undefined;
    var fileWriter = file.writer(&buff);
    const writer = &fileWriter.interface;
    writer.writeAll(data) catch |err| {
        printLn("Utils::writeAllToFile()::received error: {any} while trying to write deleteExampleUiDetached", err);
        @panic(@errorName(err));
    };
    try writer.flush();
}
