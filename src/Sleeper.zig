const std = @import("std");
const windows = std.os.windows;

extern "kernel32" fn CreateWaitableTimerExW(
    lpTimerAttributes: ?*windows.SECURITY_ATTRIBUTES,
    lpTimerName: ?windows.LPCWSTR,
    dwFlags: windows.DWORD,
    dwDesiredAccess: windows.ACCESS_MASK,
) callconv(.winapi) ?windows.HANDLE;

extern "kernel32" fn SetWaitableTimerEx(
    hTimer: ?windows.HANDLE,
    lpDueTime: ?*const windows.LARGE_INTEGER,
    lPeriod: windows.LONG,
    pfnCompletionRoutine: ?*const fn (?windows.LPVOID, windows.DWORD, windows.DWORD) callconv(.winapi) void,
    lpArgToCompletionRoutine: ?windows.LPVOID,
    WakeContext: ?*anyopaque,
    TolerableDelay: windows.ULONG,
) callconv(.winapi) windows.BOOL;

const CREATE_WAITABLE_TIMER_HIGH_RESOLUTION = 0x00000002;
const TIMER_ALL_ACCESS = windows.ACCESS_MASK.Specific.Timer.ALL_ACCESS;

const Sleeper = @This();

hTimer: windows.HANDLE,

pub fn init() !Sleeper {
    return .{
        .hTimer = CreateWaitableTimerExW(
            null,
            null,
            CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,
            TIMER_ALL_ACCESS,
        ) orelse return windows.unexpectedError(windows.GetLastError()),
    };
}

pub fn deinit(self: Sleeper) void {
    windows.CloseHandle(self.hTimer);
}

pub fn sleep(self: Sleeper, duration: std.Io.Duration) !void {
    std.debug.assert(duration.toMilliseconds() <= std.math.maxInt(i32));

    if (duration.nanoseconds < 1) return;

    const due_time: windows.LARGE_INTEGER = @intCast(-@divTrunc(duration.nanoseconds, 100));
    if (SetWaitableTimerEx(self.hTimer, &due_time, 0, null, null, null, 0) == .FALSE) {
        return windows.unexpectedError(windows.GetLastError());
    }

    const infinite_timeout: windows.LARGE_INTEGER = std.math.minInt(windows.LARGE_INTEGER);
    switch (windows.ntdll.NtWaitForSingleObject(self.hTimer, .FALSE, &infinite_timeout)) {
        windows.NTSTATUS.WAIT_0 => {},
        else => |status| return windows.unexpectedStatus(status),
    }
}

test "sleep 1ms" {
    const io = std.testing.io;

    const sleeper: Sleeper = try .init();
    defer sleeper.deinit();

    const start = std.Io.Timestamp.now(io, .awake);

    try sleeper.sleep(.fromMilliseconds(1));

    const elapsed = start.untilNow(io, .awake);
    // std.debug.print("{d}\n", .{elapsed.toMicroseconds()});

    try std.testing.expect(elapsed.toMicroseconds() < 2000);
}
