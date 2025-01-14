const std = @import("std");
const print = std.debug.print;
const time = std.time;
const fs = std.fs;
const io = std.io;
const Utils = @import("../utils/utils.zig");
const Types = @import("../types/types.zig");
const builtIn = @import("builtin");

pub const Logger = struct {
    const Self = @This();
    logDir: fs.Dir = undefined,
    logDirPath: []const u8 = "Logs",
    logData: LoggerData = undefined,
    logFile: fs.File = undefined,
    fileName: []const u8 = "",

    pub fn init(dir: []const u8) !Self {
        var logger = Logger{};
        if (dir.len > 0) logger.logDirPath = dir;
        const res = Utils.makeDirPath(Utils.getCWD(), dir);
        if (!res.Ok) {
            print("Logger::init()::error creating Logs directory:{s}", .{res.Err});
            @panic("Logger::init()::error creating log directory exiting program...");
        }
        const today = Utils.fromTimestamp(@intCast(time.timestamp()));
        const max_len = 14;
        var buf: [max_len]u8 = undefined;
        logger.fileName = std.fmt.bufPrint(&buf, "{}_{}_{}.log", .{ today.year, today.month, today.day }) catch |e| {
            print("Logger::init()::err:{any}\n", .{e});
            @panic("Logger::init()::error creating fileB=Name exiting program...\n");
        };
        const createFileData = try Utils.createFile(Utils.getCWD(), logger.logDirPath, logger.fileName, null);
        logger.logData = LoggerData.init();
        logger.logDir = createFileData.dir;
        logger.logFile = createFileData.file;
        return logger;
    }
    pub fn info(self: *Self, message: []const u8, data: anytype) !void {
        try self.logData.info(self.logFile, message, data);
    }
    pub fn warn(self: *Self, message: []const u8, data: anytype) !void {
        try self.logData.warn(self.logFile, message, data);
    }
    pub fn err(self: *Self, message: []const u8, data: anytype) !void {
        try self.logData.err(self.logFile, message, data);
    }
    pub fn fatal(self: *Self, message: []const u8, data: anytype) !void {
        try self.logData.fatal(self.logFile, message, data);
    }
    pub fn closeDirAndFiles(self: *Self) void {
        self.logDir.close();
        self.logFile.close();
    }
    pub fn writeToStdOut(self: *Self) !void {
        var buf: [1024]u8 = undefined;
        const data = try self.logDir.readFile("driver.log", &buf);
        const outw = std.io.getStdOut().writer();
        try outw.print("{s}\n", .{data});
    }
};

const LoggerData = struct {
    time: []const u8 = "",
    level: []const u8 = Types.LogLevels.get(0),
    message: []const u8 = "",
    data: ?[]const u8 = "",
    const Self = @This();

    pub fn init() LoggerData {
        return LoggerData{};
    }
    pub fn info(self: *Self, file: fs.File, message: []const u8, data: anytype) !void {
        try self.setValues(file, Types.LogLevels.INFO, message, data);
    }
    pub fn warn(self: *Self, file: fs.File, message: []const u8, data: anytype) !void {
        try self.setValues(file, Types.LogLevels.WARNING, message, data);
    }
    pub fn err(self: *Self, file: fs.File, message: []const u8, data: anytype) !void {
        try self.setValues(file, Types.LogLevels.ERROR, message, data);
    }
    pub fn fatal(self: *Self, file: fs.File, message: []const u8, data: anytype) !void {
        try self.setValues(file, Types.LogLevels.FATAL, message, data);
    }
    fn setValues(self: *Self, file: fs.File, level: Types.LogLevels, message: []const u8, data: anytype) !void {
        switch (level) {
            Types.LogLevels.INFO => self.level = Types.LogLevels.get(0),
            Types.LogLevels.WARNING => self.level = Types.LogLevels.get(1),
            Types.LogLevels.ERROR => self.level = Types.LogLevels.get(2),
            Types.LogLevels.FATAL => self.level = Types.LogLevels.get(3),
        }
        self.message = message;
        var buf: [20]u8 = undefined;
        const timeStamp = try std.fmt.bufPrint(&buf, "{s}", .{Utils.toRFC3339(Utils.fromTimestamp(@intCast(time.timestamp())))});
        self.time = timeStamp;
        try self.createJson(file, data);
    }
    fn convertToString(_: *Self, buf: *[4]u8, arrayList: *std.ArrayList(u8), T: ?type, data: anytype) ![]const u8 {
        if (T) |d| {
            const typeInfo = @typeInfo(d);
            if (typeInfo != .Null) {
                if (typeInfo == .Struct) {
                    try std.json.stringify(@as(d, data), .{ .emit_null_optional_fields = false }, arrayList.writer());
                    return @as([]const u8, arrayList.items);
                } else if (typeInfo == .ComptimeInt) {
                    return try Utils.formatString(4, buf, "{d}", .{@as(d, data)});
                } else if (typeInfo == .ComptimeFloat) {
                    return try Utils.formatString(4, buf, "{f}", .{@as(d, data)});
                } else if (typeInfo == .Int) {
                    return try Utils.formatString(4, buf, "{d}", .{@as(d, data)});
                } else if (typeInfo == .Float) {
                    return try Utils.formatString(4, buf, "{f}", .{@as(d, data)});
                } else if (typeInfo == .Pointer) {
                    const isConst = typeInfo.Pointer.is_const;
                    const child = typeInfo.Pointer.child;
                    const size = typeInfo.Pointer.size;
                    if (isConst and @TypeOf(size) == std.builtin.Type.Pointer.Size) {
                        if (child == u8 or child == [data.len:0]u8) {
                            return @as([]const u8, data);
                        }
                        return @as([]const u8, data);
                    }
                }
            }
        }
        return "";
    }
    fn createJson(self: *Self, file: fs.File, data: anytype) !void {
        var intBuf: [4]u8 = undefined;
        var bufArrayList: [1024]u8 = undefined;
        var fbaArrayList = std.heap.FixedBufferAllocator.init(&bufArrayList);
        var arrayList = try std.ArrayList(u8).initCapacity(fbaArrayList.allocator(), 1024);
        defer arrayList.deinit();
        const d = try self.convertToString(&intBuf, &arrayList, @TypeOf(data), data);
        self.data = d;
        var buf: [1024]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var string = try std.ArrayList(u8).initCapacity(fba.allocator(), buf.len);
        try std.json.stringify(self.*, .{ .emit_null_optional_fields = false }, string.writer());
        try writeToFile(file, string.items);
    }
    fn writeToFile(file: fs.File, bytes: []const u8) !void {
        var bufWriter = std.io.bufferedWriter(file.writer());
        const writer = bufWriter.writer();
        _ = try file.seekFromEnd(0);
        _ = try writer.print("{s}\n", .{bytes});
        try bufWriter.flush();
        const stdout_file = std.io.getStdOut().writer();
        var bw = std.io.bufferedWriter(stdout_file);
        const stdout = bw.writer();
        try stdout.print("{s}\n", .{bytes});
        try bw.flush(); // don't forget to flush!
    }
};
