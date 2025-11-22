const std = @import("std");

pub fn CreateQueue(comptime T: type) type {
    return struct {
        const Self = @This();
        alloc: std.mem.Allocator = undefined,
        list: std.ArrayList(T) = undefined,
        head: isize = -1,
        tail: isize = -1,
        size: isize = 0,
        capacity: isize = 0,

        pub fn init(allocator: std.mem.Allocator, comptime capacity: usize) !Self {
            return Self{
                .alloc = allocator,
                .list = try std.ArrayList(T).initCapacity(allocator, capacity),
                .capacity = capacity,
            };
        }
        pub fn deinit(self: *Self) void {
            self.list.deinit(self.alloc);
        }
        pub fn enqueue(self: *Self, value: T) !void {
            if (self.isFull()) {
                return;
            }
            if (self.isEmpty()) {
                self.head = 0;
            }
            // self.tail = (self.tail + 1) % self.capacity;
            // try self.list.replaceRange(self.alloc, self.tail, self.list.items.len, value);
            self.tail = @as(isize, @mod((self.tail + 1), self.capacity));
            try self.list.replaceRange(self.alloc, @as(usize, @intCast(self.tail)), self.list.items.len, value);
            self.size += 1;
        }
        pub fn deQueue(self: *Self) T {
            if (self.isEmpty()) {
                return null;
            }
            return self.list.orderedRemove(0);
        }
        pub fn peek(self: *Self) T {
            if (self.isEmpty()) {
                return -1;
            }
            return self.list.items[self.head];
        }
        fn isEmpty(self: *Self) bool {
            return self.size == 0;
        }
        fn isFull(self: *Self) bool {
            return self.size == self.capacity;
        }
    };
}
