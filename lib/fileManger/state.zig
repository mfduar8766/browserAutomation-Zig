const std = @import("std");
const Utils = @import("../utils/utils.zig");
const time = std.time;

const TestInformation = struct {
    name: []const u8 = "SAMPLE",
    location: []const u8 = "SAMPLE",
};

const AppState = struct {
    const Self = @This();
    initializedAt: []const u8 = undefined,
    testInformation: TestInformation = TestInformation{},
    pub fn init() Self {
        return Self{};
    }
};

pub const State = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    state: AppState = AppState.init(),
    pub fn init(allocator: std.mem.Allocator) !Self {
        const date = Utils.toRFC3339(Utils.fromTimestamp(@intCast(time.timestamp())));
        var state = Self{ .allocator = allocator };
        const bytes = state.allocator.alloc(u8, date.len) catch |e| {
            return e;
        };
        std.mem.copyForwards(u8, bytes, &date);
        state.state.initializedAt = @as([]const u8, bytes);
        return state;
    }
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.state.initializedAt);
    }
};
