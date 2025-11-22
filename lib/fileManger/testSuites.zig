const std = @import("std");
const Utils = @import("../utils/utils.zig");
const time = std.time;
const AutoHashMap = std.hash_map.AutoHashMap;
const StringHasMap = std.StringHashMap;
const Tree = @import("../tree/tree.zig");

//allocator.alloc(T, count): Allocates a raw, uninitialized block of memory on the heap large enough to hold count items of type T.
//You must then manually initialize every element.
//allocator.dupe(T, slice): Allocates memory on the heap and then copies the data from the source slice into the newly allocated heap memory.

// const TestSuite = struct {
//     name: []const u8,
//     path: []const u8,
// };
// const SuitesContainer = struct { suites: []TestSuite = undefined };
// const AppState = struct { suites: []TestSuite };

pub const TestSuites = struct {
    const Self = @This();
    const testFolderName: []const u8 = "tests";
    // const testSuiteFileName: []const u8 = "tests.json";
    const stateFileName: []const u8 = "state.json";
    const folder: []const u8 = "folder";
    const file: []const u8 = "file";
    allocator: std.mem.Allocator,
    // state: *AppState = undefined,
    lock: std.Thread.Mutex = std.Thread.Mutex{},
    fileTree: ?*Tree.Tree([]const u8) = null,

    pub fn init(allocator: std.mem.Allocator) !Self {
        const root_dirType = try Utils.copyString(allocator, folder);
        const root_name = try Utils.copyString(allocator, testFolderName);
        const root_path = try Utils.copyString(allocator, testFolderName);
        const root_value = Tree.TreeNodeValues([]const u8).init(
            root_dirType,
            root_name,
            root_path,
        );
        var testSuites = Self{
            .allocator = allocator,
            .fileTree = try Tree.Tree([]const u8).init(allocator, root_value),
        };
        //TODO: NOT SURE IF THIS IS NEEDED
        // const formattedDate = Utils.toRFC3339(Utils.fromTimestamp(@intCast(time.timestamp())));
        // const formattedDateBytes = try state.allocator.dupe(u8, &formattedDate);
        // state.state.initializedAt = @as([]const u8, formattedDateBytes);
        const cwd = Utils.getCWD();
        try testSuites.handleInit(cwd);
        return testSuites;
    }
    pub fn deinit(self: *Self) void {
        std.debug.print("DEINIT TESTSUITES\n", .{});
        // self.allocator.destroy(self.state);
        if (self.fileTree != null) {
            self.fileTree.?.deinit();
        }
    }
    pub fn runSelectedTest(self: *Self, testName: []const u8) !void {
        if (self.fileTree) |fileTree| {
            if (try fileTree.find(testName)) |child| {
                std.debug.print("TestSuites::runSelectedTest()::running test {s}\n", .{child.value.path});
            } else {
                std.debug.print("TestSuites::runSelectedTest()::test doesnt not exist\n", .{});
            }
        }
    }
    fn handleInit(self: *Self, cwd: std.fs.Dir) !void {
        Utils.dirExists(cwd, testFolderName) catch |e| {
            @panic(@errorName(e));
        };
        // Utils.fileExists(cwd, testSuiteFileName) catch |er| {
        //     @panic(@errorName(er));
        // };
        // const parsed = Utils.readAndParseFile(
        //     AppState,
        //     self.allocator,
        //     cwd,
        //     testSuiteFileName,
        // ) catch |err| {
        //     @panic(@errorName(err));
        // };
        // defer parsed.deinit();
        // const copyPtr = try self.allocator.create(AppState);
        // errdefer self.allocator.destroy(copyPtr);
        // const parsed_app_state = parsed.value;
        // const dupe_suites = try self.allocator.dupe(TestSuite, parsed_app_state.suites);
        // errdefer self.allocator.free(dupe_suites);
        // copyPtr.* = AppState{
        //     .suites = dupe_suites, // Assign the duplicated slice
        // };
        // self.state = copyPtr;
        var testsDir = try cwd.openDir(testFolderName, .{ .access_sub_paths = true, .iterate = true });
        defer testsDir.close();
        // const root_dirType = try Utils.copyString(self.allocator, folder);
        // const root_name = try Utils.copyString(self.allocator, testFolderName);
        // const root_path = try Utils.copyString(self.allocator, testFolderName);
        // const root_value = Tree.TreeNodeValues([]const u8).init(
        //     root_dirType,
        //     root_name,
        //     root_path,
        // );
        // self.fileTree = try Tree.Tree([]const u8).init(self.allocator, root_value);
        try self.walkDir(
            testsDir,
            testFolderName,
            self.fileTree.?.root.?,
        );
        // const treeFile = try cwd.createFile("newFile.json", .{});
        // defer treeFile.close();
        // try treeFile.chmod(0o664);
        // var buf: [Utils.MAX_BUFF_SIZE * 8]u8 = undefined;
        // var fba = std.heap.FixedBufferAllocator.init(&buf);
        // var out = std.io.Writer.Allocating.init(fba.allocator());
        // const writter = &out.writer;
        // defer out.deinit();
        // try std.json.Stringify.value(
        //     self.fileTree.?.root.?,
        //     .{ .emit_null_optional_fields = false, .whitespace = .indent_2 },
        //     writter,
        // );
        // treeFile.writeAll(out.written()) catch |errr| {
        //     @panic(@errorName(errr));
        // };
    }
    pub fn walkDir(
        self: *Self,
        dir: std.fs.Dir,
        path_prefix: []const u8,
        parentNode: *Tree.TreeNode([]const u8),
    ) !void {
        var entries = dir.iterate();
        const allocator = parentNode.allocator;
        while (try entries.next()) |entry| {
            // Skip '.' and '..' entries
            if (Utils.eql(u8, entry.name, ".") or Utils.eql(u8, entry.name, "..")) continue;
            switch (entry.kind) {
                .file => {
                    var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
                    const fullPath_heap = try Utils.formatStringAndCopy(
                        allocator,
                        Utils.MAX_BUFF_SIZE,
                        &buf,
                        "{s}/{s}",
                        .{
                            path_prefix,
                            entry.name,
                        },
                    );
                    const name_heap = try Utils.copyString(allocator, entry.name);
                    const dirType_heap = try Utils.copyString(allocator, file);
                    const child = try parentNode.addChild(
                        Tree.TreeNodeValues([]const u8).init(
                            dirType_heap,
                            name_heap,
                            fullPath_heap,
                        ),
                    );
                    std.debug.print("  [Inserted File]: Name: {s}, Path: {s}\n", .{ child.value.name, child.value.path });
                },
                .directory => {
                    var buf: [Utils.MAX_BUFF_SIZE]u8 = undefined;
                    const fullPath_heap = try Utils.formatStringAndCopy(
                        allocator,
                        Utils.MAX_BUFF_SIZE,
                        &buf,
                        "{s}/{s}",
                        .{
                            path_prefix,
                            entry.name,
                        },
                    );
                    const name_heap = try Utils.copyString(allocator, entry.name);
                    const dirType_heap = try Utils.copyString(allocator, "folder");

                    // 1. Insert the new directory as a child of parentNode
                    const newChildNode = try parentNode.addChild(
                        Tree.TreeNodeValues([]const u8).init(
                            dirType_heap, // Changed from 'folder' constant to string literal
                            name_heap,
                            fullPath_heap,
                        ),
                    );
                    std.debug.print("  [Inserted Dir]: Name: {s}, Path: {s}\n", .{ newChildNode.value.name, newChildNode.value.path });

                    // 2. Open the subdirectory
                    var sub_dir = try dir.openDir(entry.name, .{});
                    defer sub_dir.close();

                    // 3. Recurse, passing the newly inserted node as the next parent
                    try self.walkDir(
                        sub_dir,
                        fullPath_heap, // The new path prefix for the recursive call
                        newChildNode, // The new parent node for the recursive call
                    );
                },
                // Ignore other file types
                else => {},
            }
        }
    }
};
