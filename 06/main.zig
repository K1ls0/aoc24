const std = @import("std");
const mem = std.mem;
const log = std.log;
const util = @import("util");
const assert = std.debug.assert;
const print = std.debug.print;

const input_path = "06/input0";

const V2 = @Vector(2, isize);

const State = enum {
    free,
    obscured,
};
const Input = struct {
    input: std.ArrayList(State),
    flags: std.ArrayList(Flags),
    width: usize,
    height: usize,
    pos: V2,

    pub fn getPos(self: *const Input, pos: V2) State {
        const i = iFromXY(pos, self.width, self.height);
        return self.input.items[i];
    }
    pub fn getFlags(self: *const Input, pos: V2) *Flags {
        const i = iFromXY(pos, self.width, self.height);
        return &self.flags.items[i];
    }
};

const Flags = struct {
    visited: VisitedState = .none,
    loopable: ?Loopable = null,
    probed: bool = false,

    pub const Loopable = enum {
        loopable,
        unloopable,
    };
    pub const VisitedState = union(enum) {
        none,
        visited_free: Dir,
        visited_obscured: Dir,
    };
};

const Dir = enum {
    up,
    right,
    down,
    left,

    pub fn rotClockwise(self: Dir) Dir {
        return switch (self) {
            .up => .right,
            .right => .down,
            .down => .left,
            .left => .up,
        };
    }
};

pub fn iFromXY(pos: V2, w: usize, h: usize) usize {
    const x = pos[0];
    const y = pos[1];
    assert(x >= 0);
    assert(y >= 0);
    assert(x < @as(isize, @intCast(w)));
    assert(y < @as(isize, @intCast(h)));
    const xu: usize = @intCast(x);
    const yu: usize = @intCast(y);
    return (yu * w) + xu;
}
pub fn xFromI(i: usize, w: usize, h: usize) isize {
    assert(i < (w * h));
    const wi: isize = @intCast(w);
    const ii: isize = @intCast(i);
    return ii % wi;
}
pub fn yFromI(i: usize, w: usize, h: usize) isize {
    assert(i < (w * h));
    const wi: isize = @intCast(w);
    const ii: isize = @intCast(i);
    return ii / wi;
}

pub fn inBounds(pos: V2, w: usize, h: usize) bool {
    const wi: isize = @intCast(w);
    const hi: isize = @intCast(h);
    return pos[0] >= 0 and pos[1] >= 0 and pos[0] < wi and pos[1] < hi;
}

pub fn main() !void {
    std.debug.print("Day 06\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const input = try std.fs.cwd().readFileAlloc(arena_alloc, input_path, 1 << 20);
    const d = blk: {
        var data = std.ArrayList(State).init(arena_alloc);
        errdefer data.deinit();

        var line_it = std.mem.splitScalar(u8, input, '\n');
        var width: usize = 0;
        var height: usize = 0;
        var pos: ?V2 = null;
        while (line_it.next()) |line| {
            if (line.len == 0) continue;
            for (line, 0..) |c, x| {
                switch (c) {
                    '^' => {
                        pos = V2{ @intCast(x), @intCast(height) };
                        try data.append(.free);
                    },
                    '.' => try data.append(.free),
                    '#' => try data.append(.obscured),
                    else => unreachable,
                }
            }
            height += 1;
            width = line.len;
        }
        break :blk Input{
            .width = width,
            .height = height,
            .pos = pos.?,
            .input = data,
            .flags = blk2: {
                var v = try std.ArrayList(Flags).initCapacity(arena_alloc, width * height);
                try v.resize(width * height);
                @memset(v.items, Flags{});
                break :blk2 v;
            },
        };
    };

    print("width: {} height: {} (initial pos: {d})\n", .{ d.width, d.height, d.pos });
    for (0..d.height) |y| {
        for (0..d.width) |x| {
            const i: usize = iFromXY(.{ @intCast(x), @intCast(y) }, d.width, d.height);
            const c: u8 = if (i == iFromXY(d.pos, d.width, d.height)) 'P' else switch (d.input.items[i]) {
                .free => '.',
                .obscured => '#',
            };
            print("{c}", .{c});
        }
        print("\n", .{});
    }

    // Solution start
    var pos = d.pos;
    var dir = Dir.up;
    while (inBounds(pos, d.width, d.height)) {
        switch (d.getPos(pos)) {
            .free => {
                const f = d.getFlags(pos);
                f.visited = .{ .visited_free = dir };
                f.loopable = probeRight(&d, pos, dir); // TODO: Fix this!
                const inc: V2 = incFromDir(dir);
                pos = pos + inc;
            },
            .obscured => {
                const prev_pos = pos - incFromDir(dir);
                d.getFlags(prev_pos).visited = .{ .visited_obscured = dir };
                dir = dir.rotClockwise();
                const inc: V2 = incFromDir(dir);
                pos = prev_pos + inc;
            },
        }
    }

    var loopable: usize = 0;
    var sum: usize = 0;
    for (d.flags.items) |f| {
        if (f.visited != .none) sum += 1;
        if (f.loopable == .loopable) loopable += 1;
    }
    printGrid(&d, .{ .visited = true, .loopable = true });
    log.info("[T01] visited {} positions", .{sum});
    log.info("[T02] loopable points: {}", .{loopable});
}

fn incFromDir(dir: Dir) V2 {
    return switch (dir) {
        .up => .{ 0, -1 },
        .right => .{ 1, 0 },
        .down => .{ 0, 1 },
        .left => .{ -1, 0 },
    };
}

fn probeRight(d: *const Input, start_pos: V2, gdir: Dir) Flags.Loopable {
    var dir = gdir.rotClockwise();
    var pos = start_pos;

    while (inBounds(pos, d.width, d.height)) {
        const flags = d.getFlags(pos);
        if (flags.probed) {
            if (flags.visited != .none) {
                return .unloopable;
            } else {
                return .loopable;
            }
        }
        flags.probed = true;

        switch (d.getPos(pos)) {
            .free => {
                switch (flags.visited) {
                    .visited_free, .visited_obscured => |fdir| {
                        if (fdir == dir) return .loopable;
                    },
                    .none => {},
                }
                const inc: V2 = incFromDir(dir);
                pos = pos + inc;
            },
            .obscured => {
                const prev_pos = pos - incFromDir(dir);
                dir = dir.rotClockwise();
                const inc: V2 = incFromDir(dir);
                pos = prev_pos + inc;
            },
        }
    }
    return .unloopable;
}

fn printGrid(d: *const Input, options: struct {
    probes: bool = false,
    loopable: bool = false,
    visited: bool = true,
    starting_pos: bool = true,
}) void {
    print("\n", .{});
    for (0..d.height) |y| {
        for (0..d.width) |x| {
            const i: usize = iFromXY(.{ @intCast(x), @intCast(y) }, d.width, d.height);
            const c: u8 = blk: {
                const flags = d.flags.items[i];
                if (options.probes) {
                    if (flags.probed) {
                        break :blk 'P';
                    }
                }
                if (options.loopable) {
                    switch (d.flags.items[i].loopable orelse .unloopable) {
                        .loopable => break :blk 'L',
                        else => {},
                    }
                }

                if (options.visited) {
                    switch (flags.visited) {
                        .visited_obscured => break :blk '+',
                        .visited_free => |dir| break :blk switch (dir) {
                            .up, .down => '|',
                            .left, .right => '-',
                        },
                        .none => {},
                    }
                }
                if (options.starting_pos) {
                    if (i == iFromXY(d.pos, d.width, d.height)) break :blk 'P';
                }

                break :blk switch (d.input.items[i]) {
                    .free => '.',
                    .obscured => '#',
                };
            };
            print("{c}", .{c});
        }
        print("\n", .{});
    }
    print("\n", .{});
}
