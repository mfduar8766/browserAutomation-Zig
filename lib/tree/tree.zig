const std = @import("std");
const Allocator = std.mem.Allocator;
const Utils = @import("../utils/utils.zig");

// // TreeNodeInterface.ts
// export interface TreeNodeInterface<T> {
//     data: T;
//     children: TreeNode<T>[];
//     parent: TreeNode<T> | null;
// }

// // TreeNode.ts
// export class TreeNode<T> implements TreeNodeInterface<T> {
//     public data: T;
//     public children: TreeNode<T>[];
//     public parent: TreeNode<T> | null;

//     constructor(data: T, parent: TreeNode<T> | null = null) {
//         this.data = data;
//         this.children = [];
//         this.parent = parent;
//     }

//     /**
//      * Adds a new child node to this node.
//      */
//     public addChild(data: T): TreeNode<T> {
//         const child = new TreeNode(data, this);
//         this.children.push(child);
//         return child;
//     }
// }

// Tree.ts
// import { TreeNode } from './TreeNode';

// export class Tree<T> {
//     public root: TreeNode<T> | null;

//     constructor(rootData: T) {
//         this.root = new TreeNode(rootData);
//     }

//     // --- Essential Methods ---

//     /**
//      * 1. Traversal: Depth-First Search (DFS)
//      * Executes a callback function on every node using DFS.
//      * @param callback Function to execute on each node's data.
//      */
//     public traverseDFS(callback: (node: TreeNode<T>) => void): void {
//         if (!this.root) return;

//         const stack: TreeNode<T>[] = [this.root];
//         while (stack.length > 0) {
//             const node = stack.pop()!;
//             callback(node);

//             // Push children onto the stack in reverse order to maintain LIFO for correct DFS order
//             for (let i = node.children.length - 1; i >= 0; i--) {
//                 stack.push(node.children[i]);
//             }
//         }
//     }

//     /**
//      * 2. Traversal: Breadth-First Search (BFS)
//      * Executes a callback function on every node using BFS.
//      * @param callback Function to execute on each node's data.
//      */
//     public traverseBFS(callback: (node: TreeNode<T>) => void): void {
//         if (!this.root) return;

//         const queue: TreeNode<T>[] = [this.root];
//         while (queue.length > 0) {
//             const node = queue.shift()!;
//             callback(node);

//             // Add all children to the queue
//             for (const child of node.children) {
//                 queue.push(child);
//             }
//         }
//     }

//     /**
//      * 3. Search Method
//      * Finds a specific node based on a predicate function using BFS.
//      * @param predicate Function that returns true for the node to be found.
//      * @returns The first matching node or null.
//      */
//     public find(predicate: (data: T) => boolean): TreeNode<T> | null {
//         if (!this.root) return null;

//         const queue: TreeNode<T>[] = [this.root];
//         while (queue.length > 0) {
//             const node = queue.shift()!;
//             if (predicate(node.data)) {
//                 return node;
//             }
//             // Add all children to the queue
//             for (const child of node.children) {
//                 queue.push(child);
//             }
//         }
//         return null;
//     }

//     /**
//      * 4. Insertion Method (Insert into a specific parent)
//      * Finds a parent node by its data and inserts a new child node.
//      * @param parentData The data of the node to become the parent.
//      * @param childData The data for the new child node.
//      * @returns The new child node or null if the parent was not found.
//      */
//     public insert(parentData: T, childData: T): TreeNode<T> | null {
//         const parentNode = this.find(data => data === parentData);
//         if (parentNode) {
//             return parentNode.addChild(childData);
//         }
//         return null;
//     }

//     /**
//      * 5. Deletion Method (Remove a subtree)
//      * Finds a node and detaches it (and its entire subtree) from its parent.
//      * @param data The data of the node to delete.
//      * @returns True if the node was successfully deleted, false otherwise.
//      */
//     public remove(data: T): boolean {
//         const nodeToRemove = this.find(d => d === data);

//         if (!nodeToRemove || !nodeToRemove.parent) {
//             // Cannot remove root node or a non-existent node with this method
//             if (nodeToRemove === this.root) {
//                 console.warn("Use a dedicated method or property to clear the entire tree (this.root = null).");
//             }
//             return false;
//         }

//         const parent = nodeToRemove.parent;
//         const index = parent.children.findIndex(child => child === nodeToRemove);

//         if (index > -1) {
//             parent.children.splice(index, 1);
//             nodeToRemove.parent = null; // Detach for garbage collection
//             return true;
//         }
//         return false;
//     }
// }

pub fn TreeNodeValues(comptime T: type) type {
    return struct {
        const Self = @This();
        dirType: T,
        name: T,
        path: T,

        pub fn init(
            dirType: T,
            name: T,
            path: T,
        ) Self {
            return Self{
                .dirType = dirType,
                .name = name,
                .path = path,
            };
        }
    };
}

fn TreeNode(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        value: TreeNodeValues(T),
        children: std.ArrayList(*Self),
        parent: ?*Self = null,
        filePath: std.ArrayList([]const u8),

        pub fn init(allocator: Allocator, value: TreeNodeValues(T), parent: ?*Self) !*Self {
            const tree = try allocator.create(Self);
            tree.* = Self{
                .allocator = allocator,
                .value = value,
                .children = std.ArrayList(*Self).empty,
                .parent = parent,
                .filePath = std.ArrayList([]const u8).empty,
            };
            return tree;
        }
        pub fn deinit(self: *Self) void {
            self.children.deinit(self.allocator);
            self.filePath.deinit(self.allocator);
            self.allocator.destroy(self);
        }
        pub fn addChild(self: *Self, value: TreeNodeValues(T)) !*Self {
            const child = try TreeNode(T).init(self.allocator, value, self);
            std.debug.print("ADD-CHILD: type: {s}, name: {s}, path: {S}\n", .{ value.dirType, value.name, value.path });
            try self.children.append(self.allocator, child);
            return child;
        }
    };
}

pub fn Tree(comptime T: type) type {
    return struct {
        const Self = @This();
        root: ?*TreeNode(T) = null,
        alloc: Allocator,
        pub fn init(allocator: Allocator, value: TreeNodeValues(T)) !*Self {
            const tree = try allocator.create(Self);
            tree.* = Self{
                .alloc = allocator,
                .root = try TreeNode(T).init(
                    allocator,
                    value,
                    null,
                ),
            };
            return tree;
        }
        pub fn deinit(self: *Self) void {
            if (self.root) |root| {
                root.deinit();
            }
            self.alloc.destroy(self);
        }
        pub fn insert(self: *Self, parent: T, value: TreeNodeValues(T)) !?*TreeNode(T) {
            const found = try self.find(parent);
            if (found) |t| {
                return try t.addChild(value);
            } else {
                return null;
            }
        }
        pub fn find(self: *Self, value: T) !?*TreeNode(T) {
            if (self.root == null) {
                return null;
            }
            var queue = try std.ArrayList(*TreeNode(T)).initCapacity(self.alloc, Utils.MAX_BUFF_SIZE);
            defer queue.deinit(self.alloc);
            try queue.append(self.alloc, self.root.?);
            while (queue.items.len > 0) {
                const node = queue.orderedRemove(0);
                if (Utils.eql(u8, node.value.name, value)) {
                    return node;
                } else {
                    for (node.children.items) |child| {
                        try queue.append(self.alloc, child);
                    }
                }
            }
            return null;
        }
    };
}
