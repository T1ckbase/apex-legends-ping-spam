const std = @import("std");

const Sleeper = @import("Sleeper.zig");

const host = "127.0.0.1";
const port: u16 = 42069;

const interval_ms = 14;

const commands = [_][]const u8{
    "ping_specific_type ENEMY\n",
    "ping_specific_type LOOTING\n",
    "ping_specific_type GOING\n",
    "ping_specific_type DEFENDING\n",
    "ping_specific_type WATCHING\n",
    "+ping; -ping\n",
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    std.log.info("Connecting to {s}:{d}...", .{ host, port });

    const address = std.Io.net.IpAddress.parseIp4(host, port) catch |err| {
        std.process.fatal("Failed to parse IP address: {}", .{err});
    };
    var stream = address.connect(io, .{
        .mode = .stream,
        .protocol = .tcp,
    }) catch |err| {
        std.process.fatal("Failed to connect to host: {}", .{err});
    };
    defer stream.close(io);
    var stream_writer = stream.writer(io, &.{});

    std.log.info("Connected!", .{});

    const sleeper: Sleeper = try .init();
    defer sleeper.deinit();

    while (true) {
        for (commands) |command| {
            stream_writer.interface.writeAll(command) catch |err| {
                const final_err = stream_writer.err orelse err;
                std.process.fatal("Failed to write to stream. Connection lost? Error: {}", .{final_err});
            };

            try sleeper.sleep(.fromMilliseconds(interval_ms));
        }
    }
}
