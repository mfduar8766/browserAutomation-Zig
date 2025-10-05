const std = @import("std");
const FileManager = @import("common").FileManager;
const Utils = @import("common").Utils;

pub fn main() !void {
    // A standard general-purpose allocator is required.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const value = Utils.getEnvValueByKey(allocator, "TEST_SITE_URL") catch |e| {
        Utils.printLn("received error: {}", e);
        return e;
    };
    defer allocator.free(value);
    std.debug.print("PATH: {s}\n", .{value});

    var FM = try FileManager.init(allocator);
    defer FM.deInit();
    try FM.startE2E(value);
    Utils.printLn("Sleeping for 30 seconds...", .{});
    Utils.sleep(30000);
    try FM.stopE2E();
}
