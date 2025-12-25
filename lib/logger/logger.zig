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
    allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator, dir: []const u8) !*Self {
        const loggerPtr = try allocator.create(Self);
        loggerPtr.* = Self{ .allocator = allocator };
        // var logger = Logger{};
        if (dir.len > 0) loggerPtr.logDirPath = dir;
        const res = Utils.makeDirPath(Utils.getCWD(), dir);
        if (!res.Ok) {
            print("Logger::init()::error creating Logs directory:{s}", .{res.Err});
            @panic("Logger::init()::error creating log directory exiting program...");
        }
        const today = Utils.fromTimestamp(@intCast(time.timestamp()));
        const max_len = 14;
        var buf: [max_len]u8 = undefined;
        var fmtFileBuf: [max_len]u8 = undefined;
        loggerPtr.fileName = Utils.createFileName(
            max_len,
            &buf,
            try Utils.formatString(max_len, &fmtFileBuf, "{d}_{d}_{d}", .{
                today.year,
                today.month,
                today.day,
            }),
            Types.FileExtensions.LOG,
        ) catch |e| {
            print("Logger::init()::err:{any}\n", .{e});
            @panic("Logger::init()::error creating fileB=Name exiting program...\n");
        };
        const createFileData = try Utils.createFile(
            Utils.getCWD(),
            loggerPtr.logDirPath,
            loggerPtr.fileName,
            null,
        );
        loggerPtr.logData = LoggerData.init();
        loggerPtr.logDir = createFileData.dir;
        loggerPtr.logFile = createFileData.file;
        return loggerPtr;
    }
    pub fn deinit(self: *Self) void {
        self.closeDirAndFiles();
        self.allocator.destroy(self);
    }
    pub fn info(self: *Self, comptime message: []const u8, data: anytype) !void {
        try self.logData.info(self.logFile, message, data);
    }
    pub fn warn(self: *Self, comptime message: []const u8, data: anytype) !void {
        try self.logData.warn(self.logFile, message, data);
    }
    pub fn err(self: *Self, comptime message: []const u8, data: anytype) !void {
        try self.logData.err(self.logFile, message, data);
    }
    pub fn fatal(self: *Self, comptime message: []const u8, data: anytype) !void {
        try self.logData.fatal(self.logFile, message, data);
    }
    pub fn closeDirAndFiles(self: *Self) void {
        self.logFile.close();
        self.logDir.close();
    }
};

const LoggerData = struct {
    time: []const u8 = "",
    level: []const u8 = Types.LogLevels.get(0),
    message: ?[]const u8 = null,
    data: ?[]const u8 = null,
    const Self = @This();

    pub fn init() LoggerData {
        return LoggerData{};
    }
    pub fn info(self: *Self, file: fs.File, comptime message: []const u8, data: anytype) !void {
        try self.setValues(file, Types.LogLevels.INFO, message, data);
    }
    pub fn warn(self: *Self, file: fs.File, comptime message: []const u8, data: anytype) !void {
        try self.setValues(file, Types.LogLevels.WARNING, message, data);
    }
    pub fn err(self: *Self, file: fs.File, comptime message: []const u8, data: anytype) !void {
        try self.setValues(file, Types.LogLevels.ERROR, message, data);
    }
    pub fn fatal(self: *Self, file: fs.File, comptime message: []const u8, data: anytype) !void {
        try self.setValues(file, Types.LogLevels.FATAL, message, data);
    }
    fn setValues(self: *Self, file: fs.File, level: Types.LogLevels, comptime message: []const u8, data: anytype) !void {
        switch (level) {
            Types.LogLevels.INFO => self.level = Types.LogLevels.get(0),
            Types.LogLevels.WARNING => self.level = Types.LogLevels.get(1),
            Types.LogLevels.ERROR => self.level = Types.LogLevels.get(2),
            Types.LogLevels.FATAL => self.level = Types.LogLevels.get(3),
        }
        var buf: [29]u8 = undefined;
        const timeStamp = Utils.fromTimestamp(@intCast(time.timestamp()));
        const formattedTime = try Utils.toRFC3339(29, &buf, timeStamp);
        self.time = formattedTime;
        try self.createJson(file, level, message, data);
    }
    fn createJson(self: *Self, file: fs.File, level: Types.LogLevels, comptime message: []const u8, data: anytype) !void {
        var convertToStrBuf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        const T = @TypeOf(data);
        const formattedData = try convertToString(
            level,
            Utils.MAX_BUFF_SIZE,
            &convertToStrBuf,
            T,
            data,
            message,
        );
        if (formattedData.data) |d| {
            if (d.len > 0) {
                self.data = d;
            }
        }
        self.message = formattedData.message;
        var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var out = std.io.Writer.Allocating.init(fba.allocator());
        const writter = &out.writer;
        defer out.deinit();
        try std.json.Stringify.value(
            self.*,
            .{ .emit_null_optional_fields = false },
            writter,
        );
        try writeToFile(file, out.written());
    }
    fn convertToString(
        _: Types.LogLevels,
        bufLen: comptime_int,
        buf: *[bufLen]u8,
        TData: type,
        data: anytype,
        comptime message: []const u8,
    ) !struct { data: ?[]const u8, message: []const u8 } {
        //TODO:MAYBE ADD COLORS?
        // const Red: []const u8 = "\x1b[31m";
        // const Green: []const u8 = "\x1b[32m";
        // const Yellow: []const u8 = "\x1b[33m";
        // const Orange: []const u8 = "\x1b[38;5;214m"; // 256-color orange approximation
        // const Reset: []const u8 = "\x1b[0m";
        // const newMessage = switch (level) {
        //     Types.LogLevels.INFO => Green ++ message ++ Reset,
        //     Types.LogLevels.WARNING => Yellow ++ message ++ Reset,
        //     Types.LogLevels.ERROR => Orange ++ message ++ Reset,
        //     Types.LogLevels.FATAL => Red ++ message ++ Reset,
        // };
        const typeInfo = @typeInfo(TData);
        if (typeInfo != .null) {
            if (typeInfo == .@"struct") {
                const fields = typeInfo.@"struct".fields;
                inline for (fields) |field| {
                    const fieldTypeInfo = @typeInfo(field.type);
                    if (fieldTypeInfo == .@"struct") {
                        var jsonBuf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
                        var fba = std.heap.FixedBufferAllocator.init(&jsonBuf);
                        const json = try Utils.stringify(fba.allocator(), data, .{ .emit_null_optional_fields = true });
                        const formattedMessage = try std.fmt.bufPrint(buf, message, .{json});
                        return .{ .message = @as([]const u8, formattedMessage), .data = null };
                    } else {
                        const formattedMessage = try std.fmt.bufPrint(buf, message, data);
                        return .{ .message = @as([]const u8, formattedMessage), .data = null };
                    }
                }
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
    fn writeToFile(file: fs.File, bytes: []const u8) !void {
        var buff: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var stdout_writer_wrapper = std.fs.File.stdout().writer(&buff);
        const stdout: *std.io.Writer = &stdout_writer_wrapper.interface;
        _ = try file.seekFromEnd(0);
        try Utils.writeAllToFile(file, bytes);
        _ = try file.write("\n");
        _ = try stdout.print("{s}\n", .{bytes});
        try stdout.flush();
    }
};
