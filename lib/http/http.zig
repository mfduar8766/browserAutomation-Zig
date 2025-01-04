const std = @import("std");
const http = std.http;
const Client = std.http.Client;
const Uri = std.Uri;
const RequestOptions = std.http.Client.RequestOptions;
const Types = @import("../types//types.zig");

pub const Http = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;
    const ReqOptions = struct {
        maxReaderSize: usize = 2 * 1042 * 1024,
    };
    allocator: Allocator,
    client: std.http.Client,
    reqOpts: ReqOptions,

    pub fn init(allocator: std.mem.Allocator, reqOpts: ReqOptions) Self {
        const client = Client{ .allocator = allocator };
        return Self{
            .allocator = allocator,
            .client = client,
            .reqOpts = reqOpts,
        };
    }
    pub fn deinit(self: *Self) void {
        self.client.deinit();
    }
    pub fn get(self: *Self, url: []const u8, options: RequestOptions, maxReaderSize: ?usize) ![]u8 {
        std.debug.print("Http::get()::making request to {s}\n", .{url});
        const uri = try Uri.parse(url);
        var req = try self.client.open(.GET, uri, options);
        defer req.deinit();

        try req.send();
        try req.finish();
        try req.wait();

        std.debug.print("Http::get()::statusCode:{d}, bodyLen:{?d}\n", .{ req.response.status, req.response.content_length });
        if (req.response.status != http.Status.ok) {
            return http.Client.RequestError.NetworkUnreachable;
        }
        var maxSize: usize = self.reqOpts.maxReaderSize;
        if (maxReaderSize) |max| {
            maxSize = max;
        }
        const body = try req.reader().readAllAlloc(self.allocator, maxSize);
        return body;
    }
    pub fn post(self: *Self, url: []const u8, options: RequestOptions, payload: []const u8) ![]u8 {
        if (payload.len == 0) {
            return "";
        }
        const uri = try Uri.parse(url);
        var req = try self.client.open(.POST, uri, options);
        req.transfer_encoding = .{ .content_length = payload.len };
        defer req.deinit();
        try req.send();
        try req.writeAll(payload);
        try req.finish();
        try req.wait();
        std.debug.print("REQ.POST.STATUS: {d} LEN: {any}\n", .{ req.response.status, req.response.content_length });
        if (req.response.status != http.Status.ok) {
            return http.Client.RequestError.NetworkUnreachable;
        }
        const body = try req.reader().readAllAlloc(self.allocator, self.reqOpts.maxReaderSize);
        defer self.allocator.free(body);
        return body;
    }
};
