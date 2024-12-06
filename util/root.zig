const std = @import("std");
const mem = std.mem;

pub const FileLineIter = struct {
    f: std.fs.File,

    pub fn nextLineAlloc(self: *const FileLineIter, allocator: mem.Allocator) !?[]const u8 {
        return try self.f.reader().readUntilDelimiterOrEofAlloc(allocator, '\n', 1 << 20);
    }

    pub fn deinit(self: FileLineIter) void {
        self.f.close();
    }
};

pub fn readInputLines(
    comptime T: type,
    allocator: mem.Allocator,
    path: []const u8,
    processFn: fn (allocator: mem.Allocator, i: usize, line: []const u8, o: *T) anyerror!void,
    in: *T,
) !void {
    var it = FileLineIter{
        .f = try std.fs.cwd().openFile(path, .{ .mode = .read_only }),
    };
    defer it.deinit();

    var i: usize = 0;
    while (try it.nextLineAlloc(allocator)) |line| : (i += 1) {
        defer allocator.free(line);
        const linet = std.mem.trim(u8, line, &std.ascii.whitespace);

        try processFn(allocator, i, linet, in);
    }
}

pub fn nextNonEmpty(comptime T: type, it: anytype) ?[]const T {
    const ret: ?[]const T = while_blk: while (it.next()) |c| {
        if (c.len != 0) break :while_blk c;
    } else null;
    return ret;
}

pub fn reportTime(time: u64) void {
    const time_f = @as(f64, @floatFromInt(time)) / @as(f64, @floatFromInt(std.time.ns_per_s));
    std.log.info("time needed: {d}s", .{time_f});
}
