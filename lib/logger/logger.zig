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
        var fmtFileBuf: [max_len]u8 = undefined;
        logger.fileName = Utils.createFileName(
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
            logger.logDirPath,
            logger.fileName,
            null,
        );
        logger.logData = LoggerData.init();
        logger.logDir = createFileData.dir;
        logger.logFile = createFileData.file;
        return logger;
    }
    pub fn deinit(self: *Self) void {
        self.closeDirAndFiles();
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
        var buf: [29]u8 = undefined;
        const timeStamp = Utils.fromTimestamp(@intCast(time.timestamp()));
        const formattedTime = try Utils.toRFC3339(29, &buf, timeStamp); //try std.fmt.bufPrint(&buf, "{s}", .{try Utils.toRFC3339(timeStamp)});
        self.time = formattedTime;
        try self.createJson(file, message, data);
    }
    fn createJson(self: *Self, file: fs.File, message: []const u8, data: anytype) !void {
        const bufLen = 32;
        var intBuf: [bufLen]u8 = undefined;
        var bufArrayList: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var fbaArrayList = std.heap.FixedBufferAllocator.init(&bufArrayList);
        // var messageBuf: [1024]u8 = undefined;
        const T = @TypeOf(data);
        const formattedData = try Utils.convertToString(
            fbaArrayList.allocator(),
            bufLen,
            &intBuf,
            // &messageBuf,
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
    fn writeToFile(file: fs.File, bytes: []const u8) !void {
        var buff: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var stdout_writer_wrapper = std.fs.File.stdout().writer(&buff);
        const stdout: *std.io.Writer = &stdout_writer_wrapper.interface;
        _ = try file.seekFromEnd(0);
        _ = try stdout.print("{s}\n", .{bytes});
        try stdout.flush();

        // const buffWritter = std.fs.File.stdout().writer(&buff);
        // const writter = &buffWritter.interface;
        // _ = try file.seekFromEnd(0);
        // _ = try writter.print("{s}\n", .{bytes});
        // try buffWritter.flush();

        // var bufWriter = std.io.bufferedWriter(file.writer());
        // const writer = bufWriter.writer();
        // _ = try file.seekFromEnd(0);
        // _ = try writer.print("{s}\n", .{bytes});
        // try bufWriter.flush();
        // const stdout_file = std.io.getStdOut().writer();
        // var bw = std.io.bufferedWriter(stdout_file);
        // const stdout = bw.writer();
        // try stdout.print("{s}\n", .{bytes});
        // try bw.flush();
    }
};
