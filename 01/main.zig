const std = @import("std");
const mem = std.mem;
const log = std.log;
const util = @import("util");
const assert = std.debug.assert;

const input_path = "01/input";

pub const Input = struct {
    allocator: mem.Allocator,
    first: std.ArrayListUnmanaged(i64),
    second: std.ArrayListUnmanaged(i64),
};

fn inputProcess(_: mem.Allocator, _: usize, line: []const u8, input: *Input) anyerror!void {
    var it = std.mem.tokenizeAny(u8, line, &std.ascii.whitespace);
    const first = try std.fmt.parseInt(i64, it.next().?, 10);
    const second = try std.fmt.parseInt(i64, it.next().?, 10);
    try input.first.append(input.allocator, first);
    try input.second.append(input.allocator, second);
}

pub fn main() !void {
    std.debug.print("Day 01\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var input = Input{
        .allocator = arena.allocator(),
        .first = .{},
        .second = .{},
    };
    try util.readInputLines(Input, allocator, input_path, inputProcess, &input);

    // Task 1
    //task1(&input);

    // Task 2
    try task2(arena.allocator(), &input);
}

fn task1(input: *Input) void {
    std.sort.heap(i64, input.first.items, {}, std.sort.asc(i64));
    std.sort.heap(i64, input.second.items, {}, std.sort.asc(i64));
    assert(input.first.items.len == input.second.items.len);

    var sum: u64 = 0;
    for (0..input.first.items.len) |i| {
        const diff = @abs(input.first.items[i] - input.second.items[i]);
        sum += diff;
    }
    log.info("sum: {}", .{sum});
}

fn task2(allocator: mem.Allocator, input: *Input) !void {
    var counts_right = std.AutoHashMapUnmanaged(i64, i64){};

    // Compute counts
    for (input.second.items) |item| {
        const citem = try counts_right.getOrPut(allocator, item);
        if (citem.found_existing) {
            citem.value_ptr.* += 1;
        } else {
            citem.value_ptr.* = 1;
        }
    }

    var sum: i64 = 0;
    for (0..input.first.items.len) |i| {
        const c = input.first.items[i];
        const right_count = counts_right.get(c) orelse 0;
        sum += c * right_count;
    }
    log.info("sum: {}", .{sum});
}
