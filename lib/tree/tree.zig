const std = @import("std");
const Allocator = std.mem.Allocator;

// class TreeNode<T> implements NodeData<T> {
//   public value: T;
//   public children: TreeNode<T>[] = [];
//   public parent: TreeNode<T> | null; // Optional: helps with traversal/deletion

//   constructor(value: T, parent: TreeNode<T> | null = null) {
//     this.value = value;
//     this.parent = parent;
//   }

//   // Method to easily add a child to the current node
//   addChild(value: T): TreeNode<T> {
//     const newNode = new TreeNode(value, this);
//     this.children.push(newNode);
//     return newNode;
//   }
// }

pub fn Tree(T: type) type {
    return struct {
        const Self = @This();
        const TreeNode = struct {
            allocator: Allocator,
            value: T,
            children: std.ArrayList(*TreeNode),
            parent: ?*TreeNode = null,

            pub fn init(allocator: Allocator, value: T, parent: ?*TreeNode) *TreeNode {
                const tree = try allocator.create(TreeNode);
                tree.value = value;
                tree.parent = parent.?;
                tree.allocator = allocator;
                tree.children = std.ArrayList(*TreeNode).empty;
                return tree;
            }
            pub fn addChild(self: @This(), value: T) !void {
                const newTreeNode = TreeNode.init(self.allocator, value, self);
                try self.children.append(self.allocator, newTreeNode);
            }
        };
        root: ?*TreeNode = null,
        alloc: Allocator,

        pub fn init(allocator: Allocator, value: T, parent: ?*TreeNode) !Self {
            return Self{
                .alloc = allocator,
                .root = try TreeNode.init(allocator, value, parent),
            };
        }
        pub fn deinit(self: *Self) void {
            self.alloc.destry(self.root);
        }
        pub fn find(self: *Self, _: T) ?*TreeNode {
            if (!self.root) {
                return null;
            }
            return null;
        }
    };
}
