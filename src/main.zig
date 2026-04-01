const std = @import("std");
const windows = std.os.windows;

extern "winmm" fn timeBeginPeriod(uPeriod: windows.UINT) callconv(.winapi) windows.UINT;
extern "winmm" fn timeEndPeriod(uPeriod: windows.UINT) callconv(.winapi) windows.UINT;
const TIMERR_NOERROR = 0;

const host = "127.0.0.1";
const port: u16 = 42069;

pub fn main() !void {
    if (timeBeginPeriod(1) != TIMERR_NOERROR) {
        return error.TimeBeginPeriodFailed;
    }
    defer _ = timeEndPeriod(1);

    std.log.info("Connecting to {s}:{d}...", .{ host, port });

    const address = try std.net.Address.parseIp4(host, port);
    var stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();

    std.log.info("Connected!", .{});

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
            _ = stream.writeAll(msg) catch |err| {
                std.log.err("Failed to write to connection. Connection lost? Error: {any}", .{err});
                return;
            };
            std.Thread.sleep(std.time.ns_per_ms * 1);
            // std.Thread.sleep(std.time.ns_per_us * 500);
        }
    }
}
