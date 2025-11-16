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
        try walkDir(self.allocator, tests, testFolderName);
        // self.populateTestSuites(cwd, testFolderName) catch |errr| {
        //     @panic(@errorName(errr));
        // };
    }
    fn populateTestSuites(self: *Self, dir: std.fs.Dir, dirName: []const u8) !void {
        var dirCount: usize = 1;
        var fileCount: usize = 1;
        try self.find(dir, dirName, &dirCount, &fileCount);
    }
    fn find(self: *Self, dir: std.fs.Dir, dirName: []const u8, dirCount: *usize, fileCount: *usize) !void {
        std.debug.print("Start: {s}\n", .{dirName});
        if (self.fileTree == null) {
            self.fileTree = try Tree.Tree([]const u8).init(
                self.allocator,
                Tree.TreeNodeValues([]const u8).init("folder", dirName, "tests"),
            );
        }
        // var list: std.ArrayList([]const u8) = std.ArrayList([]const u8).empty;
        // defer list.deinit(self.allocator);
        var openCurrentDir = try dir.openDir(dirName, .{ .access_sub_paths = true, .iterate = true });
        defer openCurrentDir.close();
        var itter = openCurrentDir.iterate();
        while (true) {
            const optional_entry = itter.next() catch |err| {
                return err;
            };
            if (optional_entry == null) {
                std.debug.print("\nEnd of directory {s} reached.\n", .{dirName});
                break;
            }
            // if (dirCount > self.state.suites.len) {
            //     std.debug.print("\nDirectories is greater than list len. Exiting program.\n", .{});
            //     break;
            // }
            const entry = optional_entry.?;
            std.debug.print("EntryName: {s}, Type: {any}, dirCount: {d}, fileCount: {d}\n", .{
                entry.name,
                entry.kind,
                dirCount.*,
                fileCount.*,
            });
            if (entry.kind == std.fs.File.Kind.directory) {
                self.lock.lock();
                dirCount.* += 1;
                std.debug.print("Parent: {s}, Child: {s} Kind: {any}\n", .{ dirName, entry.name, entry.kind });
                // if (list.items.len == 0) {
                //     try list.append(self.allocator, testFolderName);
                // }
                // try list.append(self.allocator, entry.name);
                // const filePath = try std.mem.join(
                //     self.allocator,
                //     "/",
                //     list.items,
                // );
                // defer self.allocator.free(filePath);
                // std.debug.print("folderPath: {s}\n", .{filePath});

                // _ = try self.fileTree.insert(
                //     dirName,
                //     Tree.TreeNodeValues([]const u8).init("folder", entry.name, filePath),
                // );

                self.lock.unlock();
                try self.find(openCurrentDir, entry.name, dirCount, fileCount);
            }
            // if (entry.kind == std.fs.File.Kind.file) {
            //     fileCount.* += 1;
            //     std.debug.print("FileName: {s}, dirName: {s}, fileCount: {d}\n", .{
            //         dirName,
            //         entry.name,
            //         fileCount.*,
            //     });
            // }
        }
    }
    pub fn walkDir(allocator: std.mem.Allocator, dir: std.fs.Dir, path_prefix: []const u8) !void {
        // 1. Get an iterator for the directory entries
        var entries = dir.iterate();

        // 2. Loop through all entries in the current directory
        while (try entries.next()) |entry| {
            const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ path_prefix, entry.name }) catch @panic("OOM during path formatting");
            defer allocator.free(full_path);
            std.debug.print("Path: {s}\n", .{full_path});

            // 3. Check the file type
            switch (entry.kind) {
                // Found a regular file
                .file => {
                    std.debug.print("  [File] {s}\n", .{full_path});
                },
                // Found a directory, so recurse!
                .directory => {
                    std.debug.print("  [Dir] {s}/\n", .{full_path});
                    // Open the subdirectory relative to the current Dir object
                    var sub_dir = try dir.openDir(entry.name, .{});
                    defer sub_dir.close();
                    // Recursive call to continue the traversal (sequential DFS)
                    try walkDir(allocator, sub_dir, full_path);
                },
                // Ignore other file types (like symlinks, pipes, etc.)
                else => {
                    // std.debug.print("  [Other] {s} ({s})\n", .{full_path, @tagName(entry.kind)});
                },
            }
        }
    }
};
