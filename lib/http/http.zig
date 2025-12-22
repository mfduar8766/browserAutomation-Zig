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

    pub fn init(allocator: std.mem.Allocator, logger: *Logger) !Self {
        const arena = std.heap.ArenaAllocator.init(allocator);
        var clientRef = Client{ .allocator = allocator };
        try Client.initDefaultProxies(&clientRef, arena.child_allocator);
        return Self{
            .allocator = allocator,
            .client = clientRef,
            .logger = logger,
        };
    }
    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }
    pub fn makeRequest(
        self: *Self,
        requestURL: []const u8,
        method: std.http.Method,
        headers: std.http.Client.Request.Headers,
        body: ?[]u8,
    ) ![]const u8 {
        try self.logger.info("Http::makeRequest()::making {s} request to {s}", .{ @tagName(method), requestURL });
        if (body) |b| {
            std.debug.print("BODY: {s}\n", .{b});
        }
        const uriStr = try Uri.parse(requestURL);
        var resultBody = std.Io.Writer.Allocating.init(self.allocator);
        defer resultBody.deinit();
        const resultBodyWriter: *std.Io.Writer = &resultBody.writer;
        const response = try self.client.fetch(.{
            .location = .{ .uri = uriStr },
            .headers = headers,
            .method = method,
            .response_writer = resultBodyWriter,
            .payload = body,
        });
        if (response.status != .ok) {
            try self.logger.err("Http::makeRequest()::statusCode:{s}", @tagName(response.status.class()));
            return http.Client.RequestError.NetworkUnreachable;
        }
        const bodyData = resultBody.written();
        try self.logger.info("Http::makeRequest()::received btypes: {d}", bodyData.len);
        return @as([]const u8, try self.allocator.dupe(u8, bodyData));
    }
};
