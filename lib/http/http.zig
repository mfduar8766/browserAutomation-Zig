const std = @import("std");
const http = std.http;
const Client = std.http.Client;
const Uri = std.Uri;
const Types = @import("../types/types.zig");
const Utils = @import("../utils/utils.zig");
const Logger = @import("../logger/logger.zig").Logger;

pub const Http = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;
    allocator: Allocator,
    client: std.http.Client,
    logger: *Logger = undefined,

    pub fn init(allocator: std.mem.Allocator, logger: *Logger) Self {
        const client = Client{
            .allocator = allocator,
        };
        return Http{
            .allocator = allocator,
            .client = client,
            .logger = logger,
        };
    }
    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }
    pub fn makeRequest(
        self: *Self,
        url: []const u8,
        method: std.http.Method,
        headers: std.http.Client.Request.Headers,
        body: ?[]u8,
    ) ![]const u8 {
        try self.logger.info("Http::makeRequest()::making {s} request to {s}", .{ @tagName(method), url });
        const uriStr = try Uri.parse("https://jsonplaceholder.typicode.com/users");
        var req = try self.client.request(method, uriStr, http.Client.RequestOptions{
            .headers = headers,
        });
        defer req.deinit();

        _ = try req.sendBodiless();

        if (body) |b| {
            _ = try req.sendBodyComplete(b);
        }

        var redirectBuf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var response = try req.receiveHead(&redirectBuf);
        if (response.head.status.class() != .success) {
            var buf: [32]u8 = undefined;
            const statusCode = try std.fmt.bufPrint(&buf, ":{s}", .{@tagName(response.head.status.class())});
            try self.logger.err("Http::makeRequest()::statusCode:{s}", statusCode);
            return http.Client.RequestError.NetworkUnreachable;
        }
        var responseBuf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        const responseBody = try response.reader(&responseBuf).readAlloc(self.allocator, Utils.MAX_BUFF_SIZE);
        defer self.allocator.free(responseBody);
        std.debug.print("RESPONSE: {s}\n", .{responseBody});
        return try self.allocator.dupe(u8, responseBody);
    }
    pub fn makeRequest2(
        self: *Self,
        responseType: type,
        url: []const u8,
        method: std.http.Method,
        headers: std.http.Client.Request.Headers,
        body: ?[]const u8,
    ) ![]const u8 {
        std.debug.print("Http::makeRequest()::making {s} request to: {s}\n", .{ @tagName(method), url });
        const uriStr = try Uri.parse("https://jsonplaceholder.typicode.com/users");
        const req = try self.client.request(method, uriStr, http.Client.RequestOptions{
            .headers = headers,
        });
        defer req.deinit();

        try req.sendBodiless();

        if (body) |b| {
            try req.sendBodyComplete(b);
        }

        var response = try req.receiveHead(&.{});

        if (response.head.status.class() != .success) {
            var buf: [32]u8 = undefined;
            const statusCode = try std.fmt.bufPrint(&buf, ":{s}", .{@tagName(response.head.status.class())});
            try self.logger.err("Http::makeRequest()::statusCode:", statusCode);
            return http.Client.RequestError.NetworkUnreachable;
        }

        var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
        var transfer_buffer: [Utils.MAX_BUFF_SIZE]u8 = undefined;
        var decompress: std.http.Decompress = undefined;

        const decompressed_body_reader = response.readerDecompressing(
            &transfer_buffer,
            &decompress,
            &decompress_buffer,
        );

        var json_reader: std.json.Reader = .init(self.allocator, decompressed_body_reader);
        defer json_reader.deinit();

        const result: std.json.Parsed(responseType) = try std.json.parseFromTokenSource(responseType, self.allocator, &json_reader, .{
            .ignore_unknown_fields = true,
        });
        defer result.deinit();

        std.debug.print("RESPONSE: {s}\n", .{result.value});

        // if (response.head.status.class() == .success) {
        //     var stdout_buffer: [0x100]u8 = undefined;
        //     var stdout = std.fs.File.stdout().writer(&stdout_buffer);
        //     for (result.value.map.keys()) |version| {
        //         try stdout.interface.print("{s}\n", .{version});
        //     }
        //     try stdout.interface.flush();
        // } else {
        //     std.log.err("request failed: {?s}", .{response.head.status.phrase()});
        // }

        // var resultBody = std.Io.Writer.Allocating.init(self.allocator);
        // defer resultBody.deinit();
        // const resultBodyWriter: *std.Io.Writer = &resultBody.writer;
        // const response = try self.client.fetch(.{
        //     .location = .{ .uri = uriStr },
        //     .headers = headers,
        //     .method = method,
        //     .response_writer = resultBodyWriter,
        //     .payload = body,
        // });
        // if (response.status != .ok) {
        //     return http.Client.RequestError.NetworkUnreachable;
        // }
        // return try self.allocator.dupe(u8, resultBody.written());
    }
};
