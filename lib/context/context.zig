const std = @import("std");

pub fn CreateContext(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            value: T,
            key: []const u8 = "",
            next: ?*Node,
        };
        allocator: std.mem.Allocator,
        head: ?*Node,
        len: u32,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .allocator = allocator, .head = null, .len = 0 };
        }
        pub fn withValue(self: *Self, key: []const u8, value: T) !void {
            var newNode = try self.allocator.create(Node);
            newNode.value = value;
            newNode.key = key;
            const current = self.head;
            newNode.next = current;
            self.head = newNode;
            self.len += 1;
        }
        pub fn getValue(self: *Self, key: []const u8) ?T {
            if (self.len == 0 or self.head == null) {
                return null;
            }
            var current = self.head;
            var value: T = undefined;
            var tries: i32 = 0;
            const MAX_TRIES: i32 = 5;
            while (current != null) {
                if (tries > MAX_TRIES) {
                    break;
                }
                if (current) |c| {
                    if (std.mem.eql(u8, c.key, key)) {
                        value = c.value;
                        break;
                    } else {
                        tries += 1;
                        current = c.next;
                        if (std.mem.eql(u8, c.key, key)) {
                            value = c.value;
                            break;
                        }
                    }
                }
            }
            return value;
        }
        pub fn cancel(self: *Self) ?T {
            // If we don't have a head, there's no value to pop!
            if (self.head == null) {
                return null;
            }
            // Grab a few temporary values of the current head
            const currentHead = self.head;
            const updatedHead = self.head.?.next;
            // Update head and decrement the length now that we're freeing ourselves of a node
            self.head = updatedHead;
            self.length -= 1;
            return currentHead.?.value;
        }
        pub fn deInit(self: *Self) void {
            if (self.head) |h| {
                self.allocator.destroy(h);
            }
        }
    };
}

pub const Context = struct {
    const Self = @This();
    const Node = struct {
        key: []const u8 = undefined,
        value: []const u8 = undefined,
        next: ?*Node = null,
    };
    allocator: std.mem.Allocator,
    head: ?*Node = null,
    len: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .allocator = allocator };
    }
    pub fn getValue(self: Self, key: []const u8) []const u8 {
        if (self.len == 0 or self.head == null) {
            return "";
        }
        var current = self.head;
        var value: []const u8 = "";
        var tries: i32 = 0;
        const MAX_TRIES: i32 = 5;
        while (current != null) {
            if (tries > MAX_TRIES) {
                break;
            }
            if (current) |c| {
                if (std.mem.eql(u8, c.key, key)) {
                    value = c.value;
                    break;
                } else {
                    tries += 1;
                    current = c.next;
                    if (std.mem.eql(u8, c.key, key)) {
                        value = c.value;
                        break;
                    }
                }
            }
        }
        return value;
    }
    pub fn cancel(self: *Self) ?[]const u8 {
        if (self.head == null) {
            return;
        }
        const currentHead = self.head;
        const updatedHead = self.head.?.next;
        self.head = updatedHead;
        self.len -= 1;
        return currentHead.?.value;
    }
    pub fn len(self: *Self) i32 {
        return self.len;
    }
    pub fn deInit(self: *Self) void {
        if (self.head) |h| {
            self.allocator.destroy(h);
        }
    }
    pub fn withValue(self: *Self, key: []const u8, value: []const u8) !*const Context {
        var newNode = try self.allocator.create(Node);
        newNode.key = key;
        newNode.value = value;
        const current = self.head;
        newNode.next = current;
        self.head = newNode;
        self.len += 1;
        return self;
    }
};
