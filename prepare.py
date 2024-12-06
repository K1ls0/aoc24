#!/usr/bin/env python3

import os

NEW_FILE_TXT = """const std = @import("std");
const mem = std.mem;
const log = std.log;
const util = @import("util");
const assert = std.debug.assert;

const input_path = "{day}/input";

pub const Input = struct {{}};

fn inputProcess(allocator: mem.Allocator, i: usize, line: []const u8, input: *Input) anyerror!void {{
    _ = allocator;
    _ = i;
    _ = line;
    _ = input;
}}

pub fn main() !void {{
    std.debug.print("Day {day}\\n", .{{}});
    var gpa = std.heap.GeneralPurposeAllocator(.{{ .safety = true }}){{}};
    defer std.debug.assert(gpa.deinit() == .ok);
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var input = Input{{}};
    try util.readInputLines(Input, allocator, input_path, inputProcess, &input);
}}
"""

for i in range(24):
    day_str = f"{i+1:02d}"
    os.mkdir(day_str)

    with open(os.path.join(day_str, "main.zig"), "w") as f:
        f.write(NEW_FILE_TXT.format(day=day_str))
