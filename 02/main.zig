const std = @import("std");
const mem = std.mem;
const log = std.log;
const util = @import("util");
const testing = std.testing;
const assert = std.debug.assert;

const input_path = "02/input";

pub const Input = struct {
    list: std.ArrayList(std.ArrayList(i64)),
};

fn inputProcess(allocator: mem.Allocator, i: usize, line: []const u8, input: *Input) anyerror!void {
    _ = i;
    var it = std.mem.tokenizeAny(u8, line, &std.ascii.whitespace);

    var rep = std.ArrayList(i64).init(allocator);
    while (it.next()) |token| {
        try rep.append(try std.fmt.parseUnsigned(i64, token, 10));
    }
    try input.list.append(rep);
    assert(it.next() == null);
}

pub fn main() !void {
    std.debug.print("Day 02\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var input = Input{
        .list = std.ArrayList(std.ArrayList(i64)).init(allocator),
    };
    defer input.list.deinit();
    try util.readInputLines(Input, allocator, input_path, inputProcess, &input);
    log.info("input: {any}", .{input.list.items});

    //try task01(&input);
    try task02(&input);
}

const Dir = enum { none, dec, inc };
fn task01(input: *Input) !void {
    var safe_sum: usize = 0;
    for (input.list.items) |reports| {
        //const report = reports.items;

        log.info("new report:", .{});
        const safe = calcSafe(reports.items, null) == .safe;

        if (safe) log.info("is safe!", .{}) else log.info("is not safe!", .{});
        if (safe) safe_sum += 1;
    }

    log.info("safe reports: {}", .{safe_sum});
}

fn task02(input: *Input) !void {
    var safe_sum: usize = 0;
    report_blk: for (input.list.items) |*report| {

        //const report = std.ArrayList(i64).init(testing.allocator);

        log.info("report: {d}", .{report.items});
        if (calcSafe(report.items, null) == .safe) {
            safe_sum += 1;
            log.info("Safe!", .{});
            continue :report_blk;
        }
        for (0..report.items.len) |i| {
            log.info("Trying to skip {}", .{i});
            if (calcSafe(report.items, i) == .safe) {
                log.info("Safe!", .{});
                safe_sum += 1;
                continue :report_blk;
            }
        }
        log.info("Unsafe!", .{});
        // unsafe!
    }

    log.info("safe reports: {}", .{safe_sum});
}

fn calcSafe(report: []const i64, skip_idx: ?usize) union(enum) { safe, unsafe } {
    var direction: Dir = .none;
    for (1..report.len) |i| {
        const v0 = getIdxSkip(report, skip_idx, i - 1) orelse continue;
        const v1 = getIdxSkip(report, skip_idx, i) orelse continue;
        const diff = v1 - v0;
        const cdir: Dir = if (diff > 0) .inc else .dec;
        log.info("safe: direction: {s} {} -> {} -> {s}", .{
            @tagName(direction),
            v0,
            v1,
            @tagName(cdir),
        });
        if (@abs(diff) < 1 or @abs(diff) > 3) {
            log.info("-> unsafe: not in range", .{});
            return .unsafe;
        }

        //log.info("cdir: {s} direction: {s}", .{ @tagName(cdir), @tagName(direction) });
        switch (direction) {
            .inc => switch (cdir) {
                .inc => {},
                .dec => {
                    log.info("-> unsafe: not inc", .{});
                    return .unsafe;
                },
                .none => unreachable,
            },
            .dec => switch (cdir) {
                .dec => {},
                .inc => {
                    log.info("-> unsafe: not dec", .{});
                    return .unsafe;
                },
                .none => unreachable,
            },
            .none => direction = cdir,
        }
    }
    return .safe;
}

fn getIdxSkip(
    report: []const i64,
    skip_idx: ?usize,
    idx: usize,
) ?i64 {
    const sidx: usize = if (skip_idx) |sidx| sidx else return report[idx];

    if (idx < sidx) {
        if (idx >= report.len) return null;
        return report[idx];
    } else if (idx > sidx) {
        if ((idx + 1) >= report.len) return null;
        return report[idx + 1];
    } else {
        // Skip forward
        if (idx >= (report.len - 1)) return null;
        return report[idx + 1];
    }
}

test "idxSkip.noskip" {
    const report = &.{ 1, 2, 3, 5 };
    try testing.expectEqual(1, getIdxSkip(report, null, 0));
    try testing.expectEqual(3, getIdxSkip(report, null, 2));
}

test "idxSkip.skipfirst" {
    const report = &.{ 1, 2, 3, 5 };
    try testing.expectEqual(2, getIdxSkip(report, 0, 0));
    try testing.expectEqual(3, getIdxSkip(report, 0, 1));
    try testing.expectEqual(5, getIdxSkip(report, 0, 2));
    try testing.expectEqual(null, getIdxSkip(report, 0, 3));
}

test "idxSkip.skiplast" {
    const report = &.{ 1, 2, 3, 5 };
    try testing.expectEqual(1, getIdxSkip(report, 3, 0));
    try testing.expectEqual(2, getIdxSkip(report, 3, 1));
    try testing.expectEqual(3, getIdxSkip(report, 3, 2));
    try testing.expectEqual(null, getIdxSkip(report, 3, 3));
}

test "idxSkip.skipmid" {
    const report = &.{ 1, 2, 3, 5 };
    try testing.expectEqual(1, getIdxSkip(report, 2, 0));
    try testing.expectEqual(2, getIdxSkip(report, 2, 1));
    try testing.expectEqual(5, getIdxSkip(report, 2, 2));
    try testing.expectEqual(null, getIdxSkip(report, 2, 3));
}
