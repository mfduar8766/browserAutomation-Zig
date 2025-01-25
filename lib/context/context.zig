const std = @import("std");

// pub fn CreateContext(comptime T: type) type {
//     return struct {
//         const Self = @This();
//         const Node = struct {
//             value: T,
//             key: []const u8 = "",
//             next: ?*Node,
//         };
//         allocator: std.mem.Allocator,
//         head: ?*Node,
//         len: u32,

//         pub fn init(allocator: std.mem.Allocator) Self {
//             return Self{ .allocator = allocator, .head = null, .len = 0 };
//         }
// //         pub fn withValue(self: *Self, key: []const u8, value: T) !void {
//             var newNode = try self.allocator.create(Node);
//             newNode.value = value;
//             newNode.key = key;
//             const current = self.head;
//             newNode.next = current;
//             self.head = newNode;
//             self.len += 1;
//         }
//         pub fn getValue(self: *Self, key: []const u8) ?T {
//             if (self.len == 0 or self.head == null) {
//                 return null;
//             }
//             var current = self.head;
//             var value: T = undefined;
//             var tries: i32 = 0;
//             const MAX_TRIES: i32 = 5;
//             while (current != null) {
//                 if (tries > MAX_TRIES) {
//                     break;
//                 }
//                 if (current) |c| {
//                     if (std.mem.eql(u8, c.key, key)) {
//                         value = c.value;
//                         break;
//                     } else {
//                         tries += 1;
//                         current = c.next;
//                         if (std.mem.eql(u8, c.key, key)) {
//                             value = c.value;
//                             break;
//                         }
//                     }
//                 }
//             }
//             return value;
//         }
//         pub fn cancel(self: *Self) ?T {
//             // If we don't have a head, there's no value to pop!
//             if (self.head == null) {
//                 return null;
//             }
//             // Grab a few temporary values of the current head
//             const currentHead = self.head;
//             const updatedHead = self.head.?.next;
//             // Update head and decrement the length now that we're freeing ourselves of a node
//             self.head = updatedHead;
//             self.length -= 1;
//             return currentHead.?.value;
//         }
// pub fn deInit(self: *Self) void {
//     if (self.head) |h| {
//         self.allocator.destroy(h);
//     }
// }
//     };
// }

pub fn Context(T: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            key: []const u8 = "",
            value: T,
            next: ?*Node,
        };
        allocator: std.mem.Allocator,
        head: ?*Node,
        len: u32,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .head = null,
                .len = 0,
            };
        }
        pub fn deInit(self: *Self) void {
            if (self.head) |h| {
                self.allocator.destroy(h);
            }
        }
        pub fn withValue(self: *Self, key: []const u8, value: T) !void {
            const newNode = try self.allocator.create(Node);
            newNode.* = Node{ .key = key, .value = value, .next = null };
            if (self.head == null) {
                self.head = newNode;
            } else {
                var current = self.head;
                while (current.?.*.next != null) {
                    current = current.?.*.next;
                }
                current.?.*.next = newNode;
            }
            self.len += 1;
        }
        pub fn getValue(self: *Self, key: []const u8) ?T {
            var current = self.head;
            while (current != null) {
                if (std.mem.eql(u8, current.?.*.key, key)) {
                    return current.?.*.value;
                }
                current = current.?.*.next;
            }
            return null;
        }
    };
}

// package main

// import "fmt"

// // Define the Node structure
// type Node struct {
//     Value int
//     Next  *Node
// }

// // Define the LinkedList structure
// type LinkedList struct {
//     Head *Node
// }

// // Method to append a new node at the end of the list
// func (list *LinkedList) Append(value int) {
//     newNode := &Node{Value: value}
//     if list.Head == nil {
//         list.Head = newNode
//     } else {
//         current := list.Head
//         for current.Next != nil {
//             current = current.Next
//         }
//         current.Next = newNode
//     }
// }

// // Method to prepend a new node at the beginning of the list
// func (list *LinkedList) Prepend(value int) {
//     newNode := &Node{Value: value}
//     newNode.Next = list.Head
//     list.Head = newNode
// }

// // Method to insert a node at a specific index
// func (list *LinkedList) InsertAtIndex(index int, value int) bool {
//     if index < 0 {
//         return false
//     }
//     newNode := &Node{Value: value}
//     if index == 0 {
//         newNode.Next = list.Head
//         list.Head = newNode
//         return true
//     }

//     current := list.Head
//     for i := 0; current != nil && i < index-1; i++ {
//         current = current.Next
//     }

//     if current == nil {
//         return false
//     }

//     newNode.Next = current.Next
//     current.Next = newNode
//     return true
// }

// // Method to delete a node by value
// func (list *LinkedList) Delete(value int) bool {
//     if list.Head == nil {
//         return false
//     }

//     // If the head is the node to be deleted
//     if list.Head.Value == value {
//         list.Head = list.Head.Next
//         return true
//     }

//     current := list.Head
//     for current.Next != nil && current.Next.Value != value {
//         current = current.Next
//     }

//     if current.Next == nil {
//         return false // Value not found
//     }

//     current.Next = current.Next.Next
//     return true
// }

// // Method to find a node by value
// func (list *LinkedList) Find(value int) *Node {
//     current := list.Head
//     for current != nil {
//         if current.Value == value {
//             return current
//         }
//         current = current.Next
//     }
//     return nil // Node not found
// }

// // Method to return the length of the linked list
// func (list *LinkedList) Length() int {
//     length := 0
//     current := list.Head
//     for current != nil {
//         length++
//         current = current.Next
//     }
//     return length
// }

// // Method to display the entire linked list
// func (list *LinkedList) Display() {
//     current := list.Head
//     for current != nil {
//         fmt.Print(current.Value, " -> ")
//         current = current.Next
//     }
//     fmt.Println("nil")
// }

// // Method to reverse the linked list
// func (list *LinkedList) Reverse() {
//     var prev, next *Node
//     current := list.Head
//     for current != nil {
//         next = current.Next
//         current.Next = prev
//         prev = current
//         current = next
//     }
//     list.Head = prev
// }

// func main() {
//     // Create a new linked list
//     list := &LinkedList{}

//     // Add elements using Append and Prepend
//     list.Append(10)
//     list.Append(20)
//     list.Append(30)
//     list.Prepend(5)

//     // Display the list
//     fmt.Println("Original List:")
//     list.Display()

//     // Insert a node at a specific index
//     list.InsertAtIndex(2, 15)
//     fmt.Println("\nAfter InsertAtIndex(2, 15):")
//     list.Display()

//     // Find a node by value
//     node := list.Find(20)
//     if node != nil {
//         fmt.Printf("\nFound node with value: %d\n", node.Value)
//     } else {
//         fmt.Println("\nNode not found!")
//     }

//     // Delete a node by value
//     list.Delete(15)
//     fmt.Println("\nAfter Delete(15):")
//     list.Display()

//     // Reverse the list
//     list.Reverse()
//     fmt.Println("\nAfter Reverse:")
//     list.Display()

//     // Get the length of the list
//     length := list.Length()
//     fmt.Printf("\nLength of the list: %d\n", length)
// }
