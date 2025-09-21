const std = @import("std");
const FileManager = @import("common").FileManager;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var FM = try FileManager.init(allocator);
    defer FM.deInit();
    try FM.startE2E();
    std.debug.print("FOO BAR YOLO\n", .{});
}
