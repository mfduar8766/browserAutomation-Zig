const std = @import("std");
const Utils = @import("../utils/utils.zig");
const time = std.time;
const AutoHashMap = std.hash_map.AutoHashMap;
const StringHasMap = std.StringHashMap;

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

    pub fn init(allocator: std.mem.Allocator) !Self {
        var state = Self{ .allocator = allocator };
        //TODO: NOT SURE IF THIS IS NEEDED
        // const formattedDate = Utils.toRFC3339(Utils.fromTimestamp(@intCast(time.timestamp())));
        // const formattedDateBytes = try state.allocator.dupe(u8, &formattedDate);
        // state.state.initializedAt = @as([]const u8, formattedDateBytes);
        const cwd = Utils.getCWD();
        try state.handleInit(cwd);
        std.debug.print("SUITES-LEN: {d}\n", .{state.state.suites.len});
        std.debug.print("ZERO: {s}\n", .{state.state.suites[0].path});
        std.debug.print("ONE: {s}\n", .{state.state.suites[1].path});
        return state;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self.state);
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
        self.populateTestSuites(cwd, testFolderName) catch |errr| {
            @panic(@errorName(errr));
        };
    }
    fn populateTestSuites(self: *Self, dir: std.fs.Dir, dirName: []const u8) !void {
        const openCurrentDir = try dir.openDir(dirName, .{ .access_sub_paths = true, .iterate = true });
        var itter = openCurrentDir.iterate();
        var index: usize = 0;
        while (true) {
            const optional_entry = itter.next() catch |err| {
                return err;
            };
            if (optional_entry == null) {
                std.debug.print("\nEnd of directory reached.\n", .{});
                break;
            }
            if (index > self.state.suites.len) {
                break;
            }
            const entry = optional_entry.?;
            if (entry.kind == std.fs.File.Kind.file) {
                self.lock.lock();
                std.debug.print("dirname: {s} entryName: {s} statePathIndex: {s}\n", .{
                    dirName,
                    entry.name,
                    self.state.suites[index].path,
                });
                // const folder = self.state.suites[index].path[6 .. self.state.suites[index].path.len - 11];
                // std.debug.print("FOLDER-NAME: {s}\n", .{folder});
                // const suiteFilePath = self.state.suites[index].path[0 .. self.state.suites[index].path.len - 11];
                // std.debug.print("LAST-8-CHARS: {s}\n", .{suiteFilePath});
                // const removeSpecialChars = try Utils.splitAndJoinStr(
                //     self.allocator,
                //     suiteFilePath,
                //     "/",
                //     entry.name,
                // );
                // defer self.allocator.free(removeSpecialChars);
                // const file_path = try std.mem.join(self.allocator, "/", removeSpecialChars);
                // defer self.allocator.free(file_path);
                // std.debug.print("FilePath: {s}\n", .{file_path});
                // if (self.outerFileMap.getKey(folder) == null) {
                //     std.debug.print("OUT-MAP-NO-FOLDER: {s} entry.name: {s} filePath: {s}\n", .{ folder, entry.name, file_path });
                //     try self.innerFileMap.put(entry.name, file_path);
                //     try self.outerFileMap.put(folder, self.innerFileMap.get(entry.name).?);
                // } else {
                //     if (self.innerFileMap.get(entry.name) == null) {
                //         try self.innerFileMap.put(entry.name, file_path);
                //     }
                // }
                // std.debug.print("FILE-PATH: {s}\n", .{file_path});
                // self.state.suites[index].path = file_path;
                // std.debug.print("STATE-SAVED-PATH: {s}\n", .{self.state.suites[index].path});
                // std.debug.print("MAPPPPPPPPP: {s}\n", .{self.outerFileMap.get("TestOne").?});
                self.lock.unlock();
            }
            std.debug.print("EntryName: {s} Type:{any} I: {d}\n", .{ entry.name, entry.kind, index });
            if (entry.kind == std.fs.File.Kind.directory) {
                index += 1;
                try self.populateTestSuites(openCurrentDir, entry.name);
            }
        }
    }
};
