const std = @import("std");
const windows = std.os.windows;

extern "winmm" fn timeBeginPeriod(uPeriod: windows.UINT) callconv(.winapi) windows.UINT;
extern "winmm" fn timeEndPeriod(uPeriod: windows.UINT) callconv(.winapi) windows.UINT;
const TIMERR_NOERROR = 0;

const host = "127.0.0.1";
const port: u16 = 42069;

pub fn main() !void {
    if (timeBeginPeriod(1) != TIMERR_NOERROR) {
        @panic("timeBeginPeriod failed!");
    }
    defer _ = timeEndPeriod(1);

    std.log.info("Connecting to {s}:{d}...", .{ host, port });

    const address = try std.net.Address.parseIp4(host, port);
    var socket = try std.net.tcpConnectToAddress(address);
    defer socket.close();

    std.log.info("Connected!", .{});

    var writer = socket.writer(&.{});

    const messages = [_][]const u8{
        "ping_specific_type ENEMY\n",
        "ping_specific_type LOOTING\n",
        "ping_specific_type GOING\n",
        "ping_specific_type DEFENDING\n",
        "ping_specific_type WATCHING\n",
        "+ping; -ping\n",
    };

    while (true) {
        for (messages) |msg| {
            _ = writer.interface.writeAll(msg) catch |err| {
                const final_err = if (writer.err) |write_err| write_err else err;
                std.log.err("Failed to write to socket. It's likely closed. Error: {any}", .{final_err});
                return;
            };
            std.Thread.sleep(std.time.ns_per_ms * 1);
            // std.Thread.sleep(std.time.ns_per_us * 500);
        }
    }
}
