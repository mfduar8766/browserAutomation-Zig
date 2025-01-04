const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn fizzbuzz(n: usize) ?[*:0]const u8 {
    if (n % 5 == 0) {
        if (n % 3 == 0) {
            return "fizzbuzz";
        } else {
            return "fizz";
        }
    } else if (n % 3 == 0) {
        return "buzz";
    }
    return null;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
