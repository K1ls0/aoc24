const std = @import("std");
const mem = std.mem;
const log = std.log;
const util = @import("util");
const assert = std.debug.assert;

const input_path = "05/input";

pub fn main() !void {
    std.debug.print("Day 05\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const input = try std.fs.cwd().readFileAlloc(arena_alloc, input_path, 1 << 20);
    const in = blk: {
        var ret: Input = .{
            .rules_rev = std.AutoHashMap(u32, std.ArrayList(u32)).init(arena_alloc),
            .updates = try std.ArrayList([]u32).initCapacity(arena_alloc, 100),
            .has_pages = try std.ArrayList(std.AutoHashMap(u32, void)).initCapacity(arena_alloc, 100),
            .biggest_updates = 0,
            .biggest_number = 0,
        };
        var line_it = std.mem.splitScalar(u8, input, '\n');
        var state: enum { rules, data } = .rules;
        while (line_it.next()) |line| {
            switch (state) {
                .rules => {
                    if (line.len == 0) {
                        state = .data;
                        continue;
                    }

                    var rule_it = std.mem.splitScalar(u8, line, '|');
                    const first = try std.fmt.parseUnsigned(u32, rule_it.next().?, 10);
                    const second = try std.fmt.parseUnsigned(u32, rule_it.next().?, 10);
                    assert(rule_it.next() == null);

                    const entry = try ret.rules_rev.getOrPut(second);
                    if (!entry.found_existing) {
                        entry.value_ptr.* = try std.ArrayList(u32).initCapacity(arena_alloc, 16);
                    }
                    try entry.value_ptr.append(first);
                },
                .data => {
                    var new_update = try std.ArrayList(u32).initCapacity(arena_alloc, 100);
                    errdefer new_update.deinit();
                    var new_has_pages = std.AutoHashMap(u32, void).init(arena_alloc);
                    errdefer new_has_pages.deinit();

                    var nr_it = std.mem.splitScalar(u8, line, ',');
                    while (nr_it.next()) |nr_s| {
                        if (nr_s.len == 0) continue;

                        const nr = try std.fmt.parseUnsigned(u32, nr_s, 10);
                        try new_update.append(nr);
                        try new_has_pages.put(nr, {});
                        ret.biggest_number = @max(ret.biggest_number, nr);
                    }
                    if (new_update.items.len == 0) continue;
                    ret.biggest_updates = @max(ret.biggest_updates, new_update.items.len);
                    try ret.updates.append(try new_update.toOwnedSlice());
                    try ret.has_pages.append(new_has_pages);
                },
            }
        }
        break :blk ret;
    };

    {
        var it = in.rules_rev.iterator();
        std.debug.print("rules:\n", .{});
        while (it.next()) |entry| {
            std.debug.print("\t[{}] ->", .{entry.key_ptr.*});
            for (entry.value_ptr.items) |nr| {
                std.debug.print(" {}", .{nr});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("updates: \n", .{});
        for (in.updates.items, 0..) |upd, i| {
            std.debug.print("\t[{}]:", .{i});
            for (upd) |item| {
                std.debug.print(" {}", .{item});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("max updates: {}\n", .{in.biggest_updates});
    }

    var timer = try std.time.Timer.start();
    var invalid_updates = std.ArrayList(usize).init(arena_alloc);
    defer invalid_updates.deinit();

    var sum: u64 = 0;
    for_blk: for (in.updates.items, 0..) |update, update_idx| {
        var visited = try std.DynamicBitSet.initEmpty(arena_alloc, in.biggest_number + 1);
        for (update) |item| {
            //log.info("item {} at pos {}", .{ item, i });
            if (in.rules_rev.get(item)) |needed_before_l| {
                //log.info("got rules: {any}", .{needed_before_l.items});
                if (incorrectPage(&in.has_pages.items[update_idx], needed_before_l.items, &visited) != null) {
                    //log.info("page incorrect!", .{});
                    try invalid_updates.append(update_idx);
                    continue :for_blk;
                }
            }
            visited.set(@as(usize, item));
        }
        sum += @as(u64, findMid(update));
    }
    const time = timer.lap();
    log.info("[{d}s] task01: {} (invalid updates: {any})", .{
        @as(f64, @floatFromInt(time)) / std.time.ns_per_s,
        sum,
        invalid_updates.items,
    });

    // Task 02
    timer.reset();
    sum = 0;
    for (invalid_updates.items) |update_idx| {
        const update = in.updates.items[update_idx];
        log.info("invalid sequence: {} -> {any}", .{ update_idx, update });
        var visited = try std.DynamicBitSet.initEmpty(arena_alloc, in.biggest_number + 1);
        var i: usize = 0;
        const is_correct = while_blk: while (i < update.len) {
            const item = update[i];

            //log.info("item {} at pos {}", .{ item, i });
            if (in.rules_rev.get(item)) |needed_before_l| {
                //log.info("got rules: {any}", .{needed_before_l.items});
                if (incorrectPage(&in.has_pages.items[update_idx], needed_before_l.items, &visited)) |page| {
                    log.info("page incorrect: {}!", .{page});
                    if (!swapAfterPage(update, i, page)) break :while_blk false;
                    log.info("corrected: {any}", .{update});
                    continue :while_blk;
                }
            }
            visited.set(@as(usize, item));
            i += 1;
        } else true;

        if (is_correct) {
            sum += @as(u64, findMid(update));
        }
    }
    const time2 = timer.lap();
    log.info("[{d}s] task01: {} (invalid updates: {any})", .{
        @as(f64, @floatFromInt(time2)) / std.time.ns_per_s,
        sum,
        invalid_updates.items,
    });
}

fn swapAfterPage(update: []u32, idx: usize, page: u32) bool {
    assert(idx < update.len);
    const at_idx = update[idx];
    for (idx..update.len) |i| {
        if (update[i] == page) {
            std.mem.copyForwards(u32, update[idx..i], update[idx + 1 .. i + 1]);
            update[i] = at_idx;
            return true;
        }
    }
    return false;
}

fn findMid(items: []const u32) u32 {
    assert(items.len > 0);
    const odd = (items.len & 0x1) == 1;
    if (odd) {
        return items[items.len / 2];
    } else {
        return items[(items.len / 2) - 1];
    }
}

fn incorrectPage(has_pages: *const std.AutoHashMap(u32, void), needed: []const u32, visited: *const std.DynamicBitSet) ?u32 {
    for (needed) |needed_before| {
        if (has_pages.get(needed_before) == null) continue;
        if (!visited.isSet(@as(u32, needed_before))) return needed_before;
    }
    return null;
}

const Input = struct {
    rules_rev: std.AutoHashMap(u32, std.ArrayList(u32)),
    updates: std.ArrayList([]u32),
    has_pages: std.ArrayList(std.AutoHashMap(u32, void)),
    biggest_updates: usize,
    biggest_number: u32,
};
