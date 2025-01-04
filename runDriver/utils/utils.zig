const std = @import("std");
const fs = std.fs;
const os = std.os;
const io = std.io;
const time = std.time;
const DriverOptions = @import("../driver//types.zig").Options;
const Allocator = std.mem.Allocator;
const Types = @import("../types/types.zig");
const eql = std.mem.eql;
const eqlAny = std.meta.eql;
const process = std.process;
const print = std.debug.print;

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
};

pub fn fromTimestamp(ts: u64) DateTime {
    const SECONDS_PER_DAY = 86400;
    const DAYS_PER_YEAR = 365;
    const DAYS_IN_4YEARS = 1461;
    const DAYS_IN_100YEARS = 36524;
    const DAYS_IN_400YEARS = 146097;
    const DAYS_BEFORE_EPOCH = 719468;

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

    return DateTime{ .year = year, .month = month, .day = day, .hour = @intCast(seconds_since_midnight / 3600), .minute = @intCast(seconds_since_midnight % 3600 / 60), .second = @intCast(seconds_since_midnight % 60) };
}

pub fn toRFC3339(dt: DateTime) [20]u8 {
    var buf: [20]u8 = undefined;
    _ = std.fmt.formatIntBuf(buf[0..4], dt.year, 10, .lower, .{ .width = 4, .fill = '0' });
    buf[4] = '-';
    paddingTwoDigits(buf[5..7], dt.month);
    buf[7] = '-';
    paddingTwoDigits(buf[8..10], dt.day);
    buf[10] = 'T';

    paddingTwoDigits(buf[11..13], dt.hour);
    buf[13] = ':';
    paddingTwoDigits(buf[14..16], dt.minute);
    buf[16] = ':';
    paddingTwoDigits(buf[17..19], dt.second);
    buf[19] = 'Z';

    return buf;
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

pub fn makeDirPath(dirPath: []const u8) Result {
    getCWD().makePath(dirPath) catch |e| {
        std.debug.print("Utils::FileOrDirExists()::error: {}\n", .{e});
        return createErrorStruct(false, e);
    };
    return Result{ .Err = "", .Ok = true };
}

pub fn fileExistsInDir(dir: fs.Dir, fileName: []const u8) !bool {
    var itter = dir.iterate();
    var exists = false;
    while (itter.next()) |entry| {
        if (entry) |e| {
            if (e.kind == fs.File.Kind.file and std.mem.eql(u8, e.name, fileName)) {
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

pub fn createFileName(allocator: std.mem.Allocator) ![]u8 {
    const today = fromTimestamp(@intCast(time.timestamp()));
    const strAlloc = std.fmt.allocPrint(allocator, "{}_{}_{}.log", .{ today.year, today.month, today.day });
    return strAlloc;
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

pub fn createFile(cwd: std.fs.Dir, dirName: []const u8, fileName: []const u8, mode: ?comptime_int) !void {
    var dir = try cwd.openDir(dirName, .{ .access_sub_paths = true, .iterate = true });
    comptime var modeType: comptime_int = std.fs.Dir.default_mode;
    if (mode) |m| {
        modeType = m;
    }
    const file = try dir.createFile(fileName, .{
        .truncate = false,
        .mode = modeType,
    });
    defer {
        dir.close();
        file.close();
    }
}

pub fn concatStrings(allocator: std.mem.Allocator, a: []const u8, b: []const u8) ![]u8 {
    var bytes = try allocator.alloc(u8, a.len + b.len);
    std.mem.copyForwards(u8, bytes, a);
    std.mem.copyForwards(u8, bytes[a.len..], b);
    return bytes;
}

pub fn openDir(dir: std.fs.Dir, dirName: []const u8) !fs.Dir {
    return try dir.makeOpenPath(dirName, .{ .access_sub_paths = true, .iterate = true });
}

pub fn readCmdArgs(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !std.json.Parsed(DriverOptions) {
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
    return try std.json.parseFromSlice(DriverOptions, allocator, content, .{ .ignore_unknown_fields = true });
}

pub fn fileExists(cwd: std.fs.Dir, fileName: []const u8) std.fs.Dir.AccessError!void {
    return try cwd.access(fileName, .{});
}

pub fn parseJSON(comptime T: type, allocator: Allocator, body: []const u8, options: std.json.ParseOptions) !std.json.Parsed(T) {
    return try std.json.parseFromSlice(T, allocator, body, options);
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

pub fn executeCmds(argsLen: comptime_int, allocator: std.mem.Allocator, args: *const [argsLen][]const u8) !ExecCmdResponse {
    print("Utils::executeCmds()::running {s}\n", .{args.*});
    var returnStruct = ExecCmdResponse{};
    var child = process.Child.init(args, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    var stdout = std.ArrayList(u8).init(allocator);
    var stderr = std.ArrayList(u8).init(allocator);
    defer {
        stdout.deinit();
        stderr.deinit();
    }
    try child.spawn();
    try child.collectOutput(&stdout, &stderr, 1024);
    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("Utils::executeCmds()::The following command exited with error code: {any}\n", .{code});
                returnStruct.exitCode = @as(i32, @intCast(code));
                returnStruct.message = @errorName(error.CommandFailed);
                return returnStruct;
            }
        },
        .Signal => |sig| {
            std.debug.print("Utils::executeCmds()::The following command returned signal: {any}\n", .{sig});
            returnStruct.exitCode = @as(i32, @intCast(sig));
            returnStruct.message = @errorName(error.Signal);
            return returnStruct;
        },
        else => {
            std.debug.print("Utils::executeCmds()::The following command terminated unexpectedly with error:{s}\n", .{stderr.items});
            returnStruct.exitCode = 1;
            returnStruct.message = @errorName(error.CommandFailed);
            return returnStruct;
        },
    }
    returnStruct.exitCode = 0;
    returnStruct.message = @as([]const u8, stdout.items);
    print("Utils::executeCmds()::command:: \ncode: {d} \noutput: {s}\n", .{ returnStruct.exitCode, stdout.items });
    return returnStruct;
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

pub fn checkCode(code: i32, message: []const u8) !void {
    if (code != 0) {
        @panic(message);
    }
}

pub fn printLn(comptime message: []const u8, args: anytype) void {
    if (@typeInfo(@TypeOf(args)) == .Struct) {
        print(message, args);
    } else {
        print(message, .{args});
    }
}

pub fn formatString(bufLen: comptime_int, buf: *[bufLen]u8, comptime fmt: []const u8, args: anytype) ![]const u8 {
    return @as([]const u8, try std.fmt.bufPrint(buf, fmt, args));
}

// pub fn indexOf(comptime T: type, arr: T, comptime T2: type, target: anytype) i32 {
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
