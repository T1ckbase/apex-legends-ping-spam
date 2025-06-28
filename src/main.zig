//! launch option
//! -netconport 42069

const std = @import("std");

const host = "127.0.0.1";
const port: u16 = 42069;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    std.debug.print("Connecting to {s}:{d}...\n", .{ host, port });

    var stream = try std.net.tcpConnectToHost(arena.allocator(), host, port);
    defer stream.close();

    std.debug.print("Connected!\n", .{});

    const writer = stream.writer();

    // try writer.writeBytesNTimes("ping_specific_type WATCHING\n", 5000);
    // try writer.writeAll("+jump; -jump\n");

    // for (0..1000) |i| {
    //     // std.debug.print("{}", .{i});
    //     // var buffer: [64]u8 = undefined;
    //     // const msg = try std.fmt.bufPrint(&buffer, "echo hello {}\n", .{i});
    //     // try writer.writeAll(msg);
    //     _ = i;
    //     try writer.writeAll("ping_specific_type WATCHING\n");
    //     std.time.sleep(std.time.ns_per_us * 100);
    // }

    const messages = [_][]const u8{
        "ping_specific_type ENEMY\n",
        "ping_specific_type LOOTING\n",
        "ping_specific_type GOING\n",
        "ping_specific_type DEFENDING\n",
        "ping_specific_type WATCHING\n",
        "+ping; -ping\n",
    };

    while (true) {
        const write_loop = blk: {
            for (messages) |msg| {
                _ = writer.write(msg) catch |err| break :blk err;
                std.time.sleep(std.time.ns_per_ms * 1);
            }
        };

        write_loop catch |err| {
            std.debug.print("Failed to write to socket. It's likely closed. Error: {any}\n", .{err});
            return;
        };
    }
}
