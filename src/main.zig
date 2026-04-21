const std = @import("std");
const windows = std.os.windows;

const CREATE_WAITABLE_TIMER_HIGH_RESOLUTION: windows.DWORD = 0x00000002;

extern "kernel32" fn CreateWaitableTimerExW(
    lpTimerAttributes: ?*const windows.SECURITY_ATTRIBUTES,
    lpTimerName: ?windows.LPCWSTR,
    dwFlags: windows.DWORD,
    dwDesiredAccess: windows.ACCESS_MASK,
) callconv(.winapi) ?windows.HANDLE;

extern "kernel32" fn SetWaitableTimer(
    hTimer: windows.HANDLE,
    lpDueTime: *const windows.LARGE_INTEGER,
    lPeriod: i32,
    pfnCompletionRoutine: ?*const anyopaque,
    lpArgToCompletionRoutine: ?*anyopaque,
    fResume: windows.BOOL,
) callconv(.winapi) windows.BOOL;

const host = "127.0.0.1";
const port: u16 = 42069;
const interval_ms: i32 = 14;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const timer_access: windows.ACCESS_MASK = .{
        .STANDARD = .{ .SYNCHRONIZE = true },
        .SPECIFIC = .{ .TIMER = .{ .MODIFY_STATE = true } },
    };

    const timer = CreateWaitableTimerExW(
        null,
        null,
        CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,
        timer_access,
    ) orelse timer: {
        switch (windows.GetLastError()) {
            .INVALID_PARAMETER => {
                std.log.warn("High-resolution waitable timer unsupported, falling back to standard waitable timer", .{});
                break :timer CreateWaitableTimerExW(
                    null,
                    null,
                    0,
                    timer_access,
                ) orelse return windows.unexpectedError(windows.GetLastError());
            },
            else => |err| return windows.unexpectedError(err),
        }
    };
    defer windows.CloseHandle(timer);

    const due_time: windows.LARGE_INTEGER = -(@as(windows.LARGE_INTEGER, interval_ms) * std.time.ns_per_ms / 100);
    if (SetWaitableTimer(timer, &due_time, interval_ms, null, null, .FALSE) == .FALSE) {
        return windows.unexpectedError(windows.GetLastError());
    }

    std.log.info("Connecting to {s}:{d}...", .{ host, port });

    const address = try std.Io.net.IpAddress.parseIp4(host, port);
    var stream = try address.connect(io, .{
        .mode = .stream,
        .protocol = .tcp,
    });
    defer stream.close(io);

    std.log.info("Connected!", .{});

    const messages = [_][]const u8{
        "ping_specific_type ENEMY\n",
        "ping_specific_type LOOTING\n",
        "ping_specific_type GOING\n",
        "ping_specific_type DEFENDING\n",
        "ping_specific_type WATCHING\n",
        "+ping; -ping\n",
    };

    var stream_writer = stream.writer(io, &.{});

    const infinite_timeout: windows.LARGE_INTEGER = std.math.minInt(windows.LARGE_INTEGER);

    while (true) {
        for (messages) |msg| {
            _ = stream_writer.interface.writeAll(msg) catch |err| {
                const final_err = if (stream_writer.err) |write_err| write_err else err;
                std.log.err("Failed to write to connection. Connection lost? Error: {any}", .{final_err});
                return;
            };

            switch (windows.ntdll.NtWaitForSingleObject(timer, .FALSE, &infinite_timeout)) {
                windows.NTSTATUS.WAIT_0 => {},
                else => |status| return windows.unexpectedStatus(status),
            }
        }
    }
}
