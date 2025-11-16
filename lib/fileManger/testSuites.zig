const std = @import("std");
const Utils = @import("../utils/utils.zig");
const time = std.time;
const AutoHashMap = std.hash_map.AutoHashMap;
const StringHasMap = std.StringHashMap;
const Tree = @import("../tree/tree.zig");

//allocator.alloc(T, count): Allocates a raw, uninitialized block of memory on the heap large enough to hold count items of type T.
//You must then manually initialize every element.
//allocator.dupe(T, slice): Allocates memory on the heap and then copies the data from the source slice into the newly allocated heap memory.

const TestSuite = struct {
    /// The descriptive name for the test suite (e.g., "TestOne").
    name: []const u8,
    /// The glob pattern used to locate feature files (e.g., "**/tests/TestOne/**.feature").
    path: []const u8,
};
const SuitesContainer = struct { suites: []TestSuite = undefined };
const AppState = struct { suites: []TestSuite };

pub const TestSuites = struct {
    const Self = @This();
    const testFolderName: []const u8 = "tests";
    const testSuiteFileName: []const u8 = "tests.json";
    const stateFileName: []const u8 = "state.json";
    allocator: std.mem.Allocator,
    state: *AppState = undefined,
    lock: std.Thread.Mutex = std.Thread.Mutex{},
    // foldersMap: std.hash_map.StringHashMap(std.hash_map.StringHashMap([]const u8)),
    // filesMap: std.hash_map.StringHashMap([]const u8),
    fileTree: ?*Tree.Tree([]const u8) = null,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var state = Self{
            .allocator = allocator,
            // .fileTree = try Tree.Tree([]const u8).init(
            //     allocator,
            //     null,
            // ),
        };
        //TODO: NOT SURE IF THIS IS NEEDED
        // const formattedDate = Utils.toRFC3339(Utils.fromTimestamp(@intCast(time.timestamp())));
        // const formattedDateBytes = try state.allocator.dupe(u8, &formattedDate);
        // state.state.initializedAt = @as([]const u8, formattedDateBytes);
        const cwd = Utils.getCWD();
        try state.handleInit(cwd);
        // std.debug.print("SUITES-LEN: {d}\n", .{state.state.suites.len});
        // std.debug.print("ZERO: {s}\n", .{state.state.suites[0].path});
        // std.debug.print("ONE: {s}\n", .{state.state.suites[1].path});
        return state;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self.state);
        if (self.fileTree) |fileTree| {
            fileTree.deinit();
        }
    }
    fn handleInit(self: *Self, cwd: std.fs.Dir) !void {
        Utils.dirExists(cwd, testFolderName) catch |e| {
            @panic(@errorName(e));
        };
        Utils.fileExists(cwd, testSuiteFileName) catch |er| {
            @panic(@errorName(er));
        };
        const parsed = Utils.readAndParseFile(
            AppState,
            self.allocator,
            cwd,
            testSuiteFileName,
        ) catch |err| {
            @panic(@errorName(err));
        };
        defer parsed.deinit();
        const copyPtr = try self.allocator.create(AppState);
        errdefer self.allocator.destroy(copyPtr);
        const parsed_app_state = parsed.value;
        const dupe_suites = try self.allocator.dupe(TestSuite, parsed_app_state.suites);
        errdefer self.allocator.free(dupe_suites);
        copyPtr.* = AppState{
            .suites = dupe_suites, // Assign the duplicated slice
        };
        self.state = copyPtr;
        std.debug.print("LEN: {d}\n", .{self.state.suites.len});
        // var d = try cwd.openDir("tests/TestThree", .{});
        // defer d.close();
        // var tree = try Tree.Tree([]const u8).init(
        //     self.allocator,
        //     Tree.TreeNodeValues([]const u8).init("folder", testFolderName, testFolderName),
        // );
        // defer tree.deinit();
        // _ = try tree.insert(
        //     testFolderName,
        //     Tree.TreeNodeValues([]const u8).init("folder", "testOne", "tests/testOne"),
        // );
        // const found = try tree.find("testOne");
        // if (found) |f| {
        //     std.debug.print("DIRTYPE: {s}, NAME: {s}, PATH: {s}\n", .{ f.value.dirType, f.value.name, f.value.path });
        // }
        var tests = try cwd.openDir(testFolderName, .{ .access_sub_paths = true, .iterate = true });
        defer tests.close();

        self.fileTree = try Tree.Tree([]const u8).init(
            self.allocator,
            Tree.TreeNodeValues([]const u8).init(
                "folder",
                testFolderName,
                "tests/",
            ),
        );

        try self.walkDir(self.allocator, tests, testFolderName);
        if (self.fileTree) |fileTree| {
            const found = try fileTree.find("TestThree");
            if (found) |f| {
                std.debug.print("FOUND: {s}\n", .{f.value.path});
            }
            // const file = try cwd.createFile("newFile.json", .{});
            // defer file.close();
            // try file.chmod(0o664);

            // var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
            // var fba = std.heap.FixedBufferAllocator.init(&buf);
            // var out = std.io.Writer.Allocating.init(fba.allocator());
            // const writter = &out.writer;
            // defer out.deinit();
            // try std.json.Stringify.value(
            //     fileTree,
            //     .{ .emit_null_optional_fields = false, .whitespace = .indent_2 },
            //     writter,
            // );
            // file.writeAll(out.written()) catch |errr| {
            //     @panic(@errorName(errr));
            // };
        }
    }
    pub fn walkDir(self: *Self, allocator: std.mem.Allocator, dir: std.fs.Dir, path_prefix: []const u8) !void {
        // 1. Get an iterator for the directory entries
        var entries = dir.iterate();

        // 2. Loop through all entries in the current directory
        while (try entries.next()) |entry| {
            const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path_prefix, entry.name }) catch @panic("OOM during path formatting");
            defer allocator.free(full_path);
            switch (entry.kind) {
                .file => {
                    std.debug.print("  [File] prefix: {s}, name: {s}, path: {s}\n", .{ path_prefix, entry.name, full_path });
                    if (self.fileTree) |fileTreee| {
                        if (try fileTreee.find(entry.name)) |found| {
                            _ = try found.addChild(Tree.TreeNodeValues([]const u8).init("file", entry.name, full_path));
                        }
                    }
                },
                .directory => {
                    std.debug.print("  [Dir]: prefix: {s}, name: {s}, path: {s}/\n", .{ path_prefix, entry.name, full_path });
                    if (self.fileTree) |fileTree| {
                        if (try fileTree.find(path_prefix)) |found| {
                            std.debug.print("FOUND-LOOP: {s}\n", .{found.value.path});
                            _ = try found.addChild(Tree.TreeNodeValues([]const u8).init("folder", entry.name, full_path));
                        }
                    }
                    var sub_dir = try dir.openDir(entry.name, .{});
                    defer sub_dir.close();
                    try self.walkDir(allocator, sub_dir, full_path);
                },
                // Ignore other file types (like symlinks, pipes, etc.)
                else => {
                    // std.debug.print("  [Other] {s} ({s})\n", .{full_path, @tagName(entry.kind)});
                },
            }
        }
    }
};
