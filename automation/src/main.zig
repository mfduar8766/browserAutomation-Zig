const std = @import("std");
const posix = std.posix;
pub const Driver = @import("./driver/driver.zig").Driver;
pub const DriverTypes = @import("./driver/types.zig");

pub fn GracefulShutDown() type {
    return struct {
        const Self = @This();
        var mutex: std.Thread.Mutex = std.Thread.Mutex{};
        var cond: std.Thread.Condition = std.Thread.Condition{};
        var shouldExit: bool = false;
        var thread: std.Thread = undefined;

        fn applyFunction(
            comptime F: type, // The type of the function pointer
            comptime R: type,
            f: F,
            args: anytype,
        ) R {
            // 1. Get the type information for the function F
            const type_info_F = @typeInfo(F);

            // 2. Determine the function type (FnType) by checking the active union field
            const FnTypeInfo = switch (type_info_F) {
                // If F is a function pointer type (*const fn(...)), the tag is .Pointer
                .pointer => @typeInfo(type_info_F.pointer.child),

                // If F is a direct function type (fn(...)), the tag is .Fn
                .@"fn" => type_info_F,

                // Handle all other types (should not happen for a function pointer)
                else => @compileError("F must be a function or function pointer type"),
            };

            // 3. Ensure the result is now a function type and extract its parameter list
            if (FnTypeInfo != .@"fn") {
                @compileError("Internal error: Could not extract function type.");
            }

            const RequiredArgType = FnTypeInfo.@"fn".params[0].type.?; // Get the type of the first parameter

            // --- Manual Unpacking ---

            // ... (Your previous successful logic for unpacking the single argument) ...
            const ArgsType = @TypeOf(args);
            const info = @typeInfo(ArgsType);

            // if (info != .Struct or info.@"struct".fields.len != 1) {
            //     @compileError("applyFunction expected a 1-element tuple argument (e.g., .{my_arg}).");
            // }

            // Manually extract the single field (it's currently *const T)
            const arg_const_ptr = @field(args, info.@"struct".fields[0].name);

            // Now, cast the extracted argument to the required type (e.g., *anyopaque)
            // This cast is usually safe as it converts one pointer type to another.
            const arg = @as(RequiredArgType, arg_const_ptr);

            // Call the function
            const typepInfoR = @typeInfo(R);
            if (typepInfoR == .error_union) {
                // If R is an error union, use 'try' and return the result
                try f(arg);
                // Since R is !void, we return void here
                return;
            } else {
                // Otherwise, return the direct result
                return f(arg);
            }
        }
        fn sigint_handler(sig_num: c_int) callconv(.c) void {
            _ = sig_num;
            mutex.lock();
            shouldExit = true;
            cond.signal();
            mutex.unlock();
        }
        fn waitForShutDownSignal() void {
            const sig_mask: posix.sigset_t = undefined;
            const action = posix.Sigaction{
                .handler = .{ .handler = sigint_handler },
                .mask = sig_mask,
                .flags = 0,
            };
            posix.sigaction(posix.SIG.INT, &action, null);
            std.debug.print("Listening for SIGINT (Ctrl+C)...\n", .{});
            mutex.lock();
            defer mutex.unlock();
            while (!shouldExit) {
                cond.wait(&mutex);
            }
            std.debug.print("\nSIGINT received. Shutting down gracefully.\n", .{});
        }

        pub fn init() Self {
            return Self{};
        }
        pub fn spawn(_: *Self, function: anytype, args: anytype) !void {
            thread = try std.Thread.spawn(.{}, waitForShutDownSignal, .{});
            const T = @TypeOf(function);
            const typeInfo = @typeInfo(T);
            comptime var R: type = undefined;
            if (typeInfo == .@"fn") {
                R = typeInfo.@"fn".return_type.?;
            } else if (typeInfo == .pointer) {
                const targetType = typeInfo.pointer.child;
                R = @typeInfo(targetType).@"fn".return_type.?;
            }
            try applyFunction(T, R, function, args);
        }
        ///Waits for the thread to complete, then deallocates any resources created on spawn().
        ///
        ///Once called, this consumes the Thread object and invoking any other functions on it is considered undefined behavior.
        pub fn wait(_: Self) void {
            thread.join();
        }
    };
}
