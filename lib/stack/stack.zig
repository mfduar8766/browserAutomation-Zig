const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Stack(T: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator = undefined,
        stack: std.ArrayList(T) = undefined,

        pub fn init(allocator: Allocator) !Self {
            return Self{
                .allocator = allocator,
                .stack = std.ArrayList(T).empty,
            };
        }
        pub fn deinit(self: *Self) void {
            self.stack.deinit(self.alloc);
        }
        pub fn push(self: *Self, value: T) !void {
            try self.stack.append(self.allocator, value);
        }
        pub fn pop(self: *Self) !void {
            if (self.stack.items.len > 0) {
                try self.stack.pop();
            }
        }
        pub fn peek(self: *Self) !T {
            if (self.stack.items.len > 0) {
                return try self.stack.getLast();
            }
            return null;
        }
        pub fn clear(self: *Self) void {
            self.stack.clearAndFree(self.allocator);
        }
    };
}
