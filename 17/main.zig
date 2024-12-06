const std = @import("std");
const mem = std.mem;
const log = std.log;
const util = @import("util");

const input_path = "17/input";

pub const Input = struct {};

fn inputProcess(allocator: mem.Allocator, i: usize, line: []const u8, input: *Input) anyerror!void {
    _ = allocator;
    _ = i;
    _ = line;
    _ = input;
}

pub fn main() !void {
    std.debug.print("Day 17\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var input = Input{};
    try util.readInputLines(Input, allocator, input_path, inputProcess, &input);
}
