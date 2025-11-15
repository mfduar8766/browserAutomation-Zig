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
    while (itter.next()) |entry| {
        if (entry) |e| {
            if (e.kind == fs.File.Kind.file and eql(u8, e.name, fileName)) {
                exists = true;
                break;
            }
            if (e.kind == fs.File.Kind.directory) {
                const subDir = try dir.openDir(e.name, .{ .access_sub_paths = true, .iterate = true });
                exists = try fileExistsInDir(subDir, fileName);
            }
        } else {
            @panic("Utils::fileExistsInDir()::entry does not exist");
        }
    } else |err| {
        std.debug.print("Utils::fileExistsInDir()::err:{}\n", .{err});
    }
    return exists;
}

//TODO: Make this generic??
// pub fn createFileName(
//     bufLen: comptime_int,
//     buf: *[bufLen]u8,
//     comptime fmt: []const u8,
//     args: anytype,
//     extension: Types.FileExtensions,
// ) ![]const u8 {
//     const emptyTuple = .{};
//     const combinedArgs = emptyTuple ++ args;
//     return switch (extension) {
//         Types.FileExtensions.TXT => {
//             const txtExtension = combinedArgs ++ .{".txt"};
//             return try formatString(bufLen, buf, fmt, txtExtension);
//         },
//         Types.FileExtensions.LOG => {
//             const logExtension = combinedArgs ++ .{".log"};
//             return try formatString(bufLen, buf, fmt, logExtension);
//         },
//         Types.FileExtensions.JPG => {
//             const jPegExtension = combinedArgs ++ .{".jpg"};
//             return try formatString(bufLen, buf, fmt, jPegExtension);
//         },
//         Types.FileExtensions.PNG => {
//             const pngExtension = combinedArgs ++ .{".png"};
//             return try formatString(bufLen, buf, fmt, pngExtension);
//         },
//     };
// }

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
    var fileName: []const u8 = undefined;
    const outFileLog: []const u8 = "out";
    const cleanUpFileName = if (incomingFileName.len >= 10) incomingFileName[2 .. incomingFileName.len - 3] else outFileLog;
    printLn("Utils::executeCmds()::incomingFileName: {s}", cleanUpFileName);
    const today = fromTimestamp(@intCast(time.timestamp()));
    const max_len = 100;
    var buf: [max_len]u8 = undefined;
    var fmtFileBuf: [max_len]u8 = undefined;
    fileName = createFileName(
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
        printLn("Utils::executeCmds()::err:{any}\n", .{@errorName(e)});
        @panic("Utils::executeCmds()::error creating fileB=Name exiting program...\n");
    };
    try deleteFileIfExists(getCWD(), fileName);
    const file = try getCWD().createFile(fileName, .{
        .read = false,
        .truncate = true,
    });
    try file.chmod(0o664); // 0o664 (rw-rw-r--) is safer than 777
    //CRITICAL FIX: Close the file BEFORE the shell command runs.
    file.close();
    const argv_slice = &args.*;
    const full_command = try join(allocator, " ", argv_slice);
    defer allocator.free(full_command);
    const command_str = try std.fmt.allocPrint(allocator, "{s} > {s} 2>&1", .{ full_command, fileName });
    defer allocator.free(command_str);
    var child = std.process.Child.init(&[_][]const u8{ "/bin/bash", "-c", command_str }, allocator);
    try child.spawn();
    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                printLn("Utils::executeCmds()::The following command exited with error code: {any}", .{code});
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

pub fn checkIfPortInUse(allocator: Allocator, port: i32) !ExecCmdResponse {
    var buf: [6]u8 = undefined;
    const formattedPort = try formatString(6, &buf, ":{d}", .{port});
    const args = [_][]const u8{
        "lsof", "-i", formattedPort,
    };
    return try executeCmds(3, allocator, &args);
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

/// TODO: Figure out how to add format option to logger
/// Currently format is breaking no idea why.
/// Even with if (!isDigitFormat and isDigit) it still crashes even if isDigitFormat === false and isDigit is === true
pub fn convertToString(
    allocator: Allocator,
    intBufLen: comptime_int,
    intBuf: *[intBufLen]u8,
    // messageBuf: *[1024]u8,
    T: type,
    data: anytype,
    message: []const u8,
) !struct { data: ?[]const u8, message: []const u8 } {
    const typeInfo = @typeInfo(T);
    if (typeInfo != .null) {
        const isDigitFormat = std.mem.containsAtLeast(u8, message, 1, "{d}");
        // const isStringFormat = std.mem.containsAtLeast(u8, message, 1, "{s}");
        const isDigit = (typeInfo == .comptime_float or typeInfo == .comptime_int or typeInfo == .int or typeInfo == .float);
        // print("BEFORE IF: isDigitFormat:{any} isStringFormat:{any} T:{any} typeInfo:{any} isDigit:{any}\n", .{
        //     isDigitFormat,
        //     isStringFormat,
        //     T,
        //     typeInfo,
        //     isDigit,
        // });
        if (isDigit and !isDigitFormat) {
            return .{ .data = try formatString(intBufLen, intBuf, "{d}", .{@as(T, data)}), .message = message };
        } else if (typeInfo == .@"struct") {
            var out = std.io.Writer.Allocating.init(allocator);
            const writter = &out.writer;
            defer out.deinit();
            try std.json.Stringify.value(
                @as(T, data),
                .{ .emit_null_optional_fields = false },
                writter,
            );
            return .{ .data = @as([]const u8, out.written()), .message = message };
        } else if (typeInfo == .pointer) {
            const isConst = typeInfo.pointer.is_const;
            const child = typeInfo.pointer.child;
            if (isConst and (child == u8 or child == [data.len:0]u8 or T == *const [data.len:0]u8 or T == []const u8)) {
                return .{ .data = @as([]const u8, data), .message = message };
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

/// sleep() - Takes a duration in milliseconds
pub fn sleep(durrationMs: u64) void {
    const multiplier = @as(u64, @intFromFloat(1e6));
    const duration = durrationMs * multiplier;
    time.sleep(duration);
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
        printLn("Utils::getEnvVar()::received error {}", e);
        if (e == Errors.FileNotFound) {
            return try std.process.getEnvVarOwned(allocator, key);
        }
    };
    const file = cwd.openFile(file_path, .{ .mode = .read_only }) catch |er| {
        printLn("Utils::getEnvVar()::received error {}", er);
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
    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [1024]u8 = undefined;
    var value: []const u8 = "";
    var bytes: []u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
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
                bytes = try allocator.alloc(u8, value.len);
                std.mem.copyForwards(u8, bytes, value);
                break;
            }
        }
    }
    return bytes;
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

// pub fn indexOf(comptime{}_{}_{}.log T: type, arr: T, comptime T2: type, target: anytype) i32 {
//     var index: i32 = -1;
//     var left: usize = 0;
//     const arrType = @as(@Type(@typeInfo(T)), arr);
//     const targetTypeRef = @as(@Type(@typeInfo(T2)), target);
//     var right: usize = arr.len - 1;
//     while (left <= right) {
//         index += 1;
//         var mid = left + (right - left) / 2;
//         const arrMid = @as(@Type(@typeInfo(T2)), arrType[mid]);
//         if (eql(@Type(@typeInfo(T2)), arrMid, targetTypeRef)) {
//             return @as(i32, mid);
//         } else if (mid < index) {
//             mid = mid + 1;
//             left = mid;
//         } else {
//             mid = mid - 1;
//             right = mid;
//         }
//     }
//     return -1;
// }

// const txtExtension = combinedArgs ++ .{"txt"};
// print("FFFFF: {any}\n", .{txtExtension});
// const f = try formatString(bufLen, buf, fmt, txtExtension);
// print("F: {s}\n", .{f});
// return f;

// const T = @TypeOf(args);
// const typeInfo = @typeInfo(T);
// print("TypeOf({})\n", .{T});
// if (typeInfo == .Struct) {
//     const fields = typeInfo.Struct.fields;
//     // const F = .{};
//     // const G = struct {};
//     // const gFields = @typeInfo(@TypeOf(G)).Struct.fields;
//     // const merge = fields ++ gFields;
//     // const Y = @Type(.{ .Struct = .{
//     //     .layout = .auto,
//     //     .fields = fields ++ gFields,
//     //     .is_tuple = false,
//     //     .decls = &.{},
//     // } });
//     // print("Y: {any}\n", .{Y});

//     comptime var array: [3]comptime_int = undefined;
//     // var bufArrayList: [1024]u8 = undefined;
//     // var fba = std.heap.FixedBufferAllocator.init(&bufArrayList);
//     // const allocator = fba.allocator();
//     // comptime var arrList = std.ArrayList(comptime_int).init(std.heap.page_allocator);
//     // defer arrList.deinit();
//     comptime var i = 0;
//     inline for (fields) |field| {
//         const dvalue_aligned: *align(field.alignment) const anyopaque = @alignCast(field.default_value.?);
//         const value = @as(*const field.type, @ptrCast(dvalue_aligned)).*;
//         std.log.info("name: {s} default value: {}", .{ field.name, value });
//         array[i] = value;
//         i += 1;
//         // try arrList.append(value);
//         // const new_tuple = F ++ .{ value, ".txt" };
//         // print("S: {any}\n", .{new_tuple});
//     }
//     const slice = &array;
//     print("ITEMS: {s}\n", .{slice});
//     print("TUPLE: {any}\n", .{std.meta.Tuple(slice)});
//     return "";
// }
