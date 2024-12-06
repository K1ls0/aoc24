const std = @import("std");
const mem = std.mem;
const log = std.log;
const assert = std.debug.assert;

const input_path = "04/input";
const WORD = "XMAS";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const gpa_alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const input = try std.fs.cwd().readFileAlloc(arena_alloc, input_path, 1 << 24);

    //std.debug.print("{s}\n\n", .{input});

    const width, const height = blk: {
        var line_it = std.mem.splitScalar(u8, input, '\n');
        const first_line = line_it.next().?;
        const width: isize = @intCast(first_line.len);
        var height: isize = 0;
        while (line_it.next()) |_| : (height += 1) {}
        break :blk .{ width, height };
    };

    try task01(gpa_alloc, arena_alloc, width, height, input);
    try task02(gpa_alloc, arena_alloc, width, height, input);

    //log.info("height: {} width: {}", .{ height, width });

}

fn task02(
    gpa_alloc: mem.Allocator,
    arena_alloc: mem.Allocator,
    width: isize,
    height: isize,
    input: []const u8,
) !void {
    const input_data_trimmed = try std.mem.replaceOwned(u8, arena_alloc, input, "\n", "");

    const grid = Grid{
        .width = width,
        .height = height,
        .data = std.ArrayList(u8).fromOwnedSlice(arena_alloc, input_data_trimmed),
        .mark_data = blk: {
            const data_mark = try arena_alloc.alloc(Grid.Flags, input_data_trimmed.len);
            @memset(data_mark, Grid.Flags{});
            break :blk std.ArrayList(Grid.Flags).fromOwnedSlice(
                gpa_alloc,
                data_mark,
            );
        },
    };

    var found: std.AutoHashMap(isize, void) = std.AutoHashMap(isize, void).init(gpa_alloc);
    defer found.deinit();

    var words: usize = 0;
    for_grid: for (grid.data.items, 0..) |char, i| {
        const x, const y = grid.xyFromIdx(@intCast(i));

        if (char != 'A') continue :for_grid;
        //log.info("New potential mid at ({}, {})", .{ x, y });

        const xinc_ul, const yinc_ul = comptime incFromDirection(.upleft);
        const xinc_ur, const yinc_ur = comptime incFromDirection(.upright);
        const xinc_dl, const yinc_dl = comptime incFromDirection(.downleft);
        const xinc_dr, const yinc_dr = comptime incFromDirection(.downright);

        const ul: u8 = if (grid.inBounds(x + xinc_ul, y + yinc_ul)) grid.get(x + xinc_ul, y + yinc_ul) else continue :for_grid;
        const dr: u8 = if (grid.inBounds(x + xinc_dr, y + yinc_dr)) grid.get(x + xinc_dr, y + yinc_dr) else continue :for_grid;
        const ur: u8 = if (grid.inBounds(x + xinc_ur, y + yinc_ur)) grid.get(x + xinc_ur, y + yinc_ur) else continue :for_grid;
        const dl: u8 = if (grid.inBounds(x + xinc_dl, y + yinc_dl)) grid.get(x + xinc_dl, y + yinc_dl) else continue :for_grid;

        //log.info("ul: {c} dr: {c}", .{ ul, dr });
        //log.info("ur: {c} dl: {c}", .{ ur, dl });

        const ul_dr_correct = (ul == 'M' and dr == 'S') or (ul == 'S' and dr == 'M');
        const ur_dl_correct = (ur == 'M' and dl == 'S') or (ur == 'S' and dl == 'M');

        //log.info("ul_dr: {}", .{ul_dr_correct});
        //log.info("ur_dl: {}", .{ur_dl_correct});

        if (ul_dr_correct and ur_dl_correct) words += 1;
        //try found.put(grid.idxFromXY(x, y));
    }

    // Print Grid
    //const stdout = std.io.getStdOut();
    //var writer = std.io.bufferedWriter(stdout.writer());
    //const w = writer.writer();
    //for (0..@intCast(grid.height)) |y| {
    //    for (0..@intCast(grid.width)) |x| {
    //        const flags = grid.flagsMut(@intCast(x), @intCast(y));
    //        const c = grid.get(@intCast(x), @intCast(y));
    //        try std.fmt.format(w, "{c}", .{if (!flags.is_word) c else '.'});
    //    }
    //    try std.fmt.format(w, "\n", .{});
    //}
    //try writer.flush();

    log.info("Words found: {}", .{words});
}

fn task01(
    gpa_alloc: mem.Allocator,
    arena_alloc: mem.Allocator,
    width: isize,
    height: isize,
    input: []const u8,
) !void {
    const input_data_trimmed = try std.mem.replaceOwned(u8, arena_alloc, input, "\n", "");

    const grid = Grid{
        .width = width,
        .height = height,
        .data = std.ArrayList(u8).fromOwnedSlice(arena_alloc, input_data_trimmed),
        .mark_data = blk: {
            const data_mark = try arena_alloc.alloc(Grid.Flags, input_data_trimmed.len);
            @memset(data_mark, Grid.Flags{});
            break :blk std.ArrayList(Grid.Flags).fromOwnedSlice(
                gpa_alloc,
                data_mark,
            );
        },
    };

    var found_words: std.AutoHashMap(WordPos, void) = std.AutoHashMap(WordPos, void).init(gpa_alloc);
    defer found_words.deinit();

    for (grid.data.items, 0..) |item, i| {
        const flags = &grid.mark_data.items[i];
        //if (flags.is_word) continue;

        const x, const y = grid.xyFromIdx(@intCast(i));
        const word_idx = LetterContainedInWord(WORD, item) orelse continue;
        //log.info("----> starting found {c} at {} ({}, {})", .{ WORD[word_idx], word_idx, x, y });

        inline for (comptime std.meta.tags(Direction)) |dir| for_blk: {
            const xinc, const yinc = incFromDirection(dir);
            const dir_count = switch (searchWordRec(
                &grid,
                WORD,
                @intCast(@as(isize, @intCast(word_idx)) + wordIncFromScanDir(.forward)),
                .forward,
                .{ x + xinc, y + yinc },
                dir,
            )) {
                .found => |c| c,
                .not_found => break :for_blk,
            };
            //log.info("Forward found!", .{});

            const x_neg_inc, const y_neg_inc = incFromDirection(comptime dir.negate());
            const dir_neg_count = switch (searchWordRec(
                &grid,
                WORD,
                @intCast(@as(isize, @intCast(word_idx)) + wordIncFromScanDir(.backward)),
                .backward,
                .{ x + x_neg_inc, y + y_neg_inc },
                comptime dir.negate(),
            )) {
                .found => |c| c,
                .not_found => break :for_blk,
            };
            //log.info("Backward found!", .{});
            assert(dir_count + dir_neg_count + 1 == WORD.len);

            const start_x = x + (x_neg_inc * @as(isize, @intCast(dir_neg_count)));
            const start_y = y + (y_neg_inc * @as(isize, @intCast(dir_neg_count)));

            try found_words.put(.{
                .dir = dir,
                .idx = grid.idxFromXY(start_x, start_y),
            }, {});

            //log.info("checking new word: startingLetter: {c} at ({}, {}) (w: {}) (forward dir: {s})", .{ item, x, y, word_idx, @tagName(dir) });
            //log.info("dir_neg_count: {} dir_count: {}", .{ dir_neg_count, dir_count });
            for (0..WORD.len) |j| {
                const cx = start_x + (@as(isize, @intCast(j)) * xinc);
                const cy = start_y + (@as(isize, @intCast(j)) * yinc);
                //log.info("checking at ({}, {}) (from start ({}, {}), inc: ({}, {}))", .{
                //    cx,
                //    cy,
                //    start_x,
                //    start_y,
                //    xinc,
                //    yinc,
                //});
                const cflags = grid.flagsMut(cx, cy);
                cflags.is_word = true;
            }
            flags.is_word = true;
        }
    }

    // Print Grid
    const stdout = std.io.getStdOut();
    var writer = std.io.bufferedWriter(stdout.writer());
    const w = writer.writer();
    for (0..@intCast(grid.height)) |y| {
        for (0..@intCast(grid.width)) |x| {
            const flags = grid.flagsMut(@intCast(x), @intCast(y));
            const c = grid.get(@intCast(x), @intCast(y));
            try std.fmt.format(w, "{c}", .{if (!flags.is_word) c else '.'});
        }
        try std.fmt.format(w, "\n", .{});
    }
    try writer.flush();

    log.info("Words found: {}", .{found_words.count()});
}

const WordPos = struct {
    idx: usize,
    dir: Direction,
};

fn searchWordRec(
    grid: *const Grid,
    comptime word: []const u8,
    word_idx: isize,
    comptime word_direction: ScanDir,
    start: struct { isize, isize },
    comptime direction: Direction,
) union(enum) { found: usize, not_found } {
    //log.info("searchWordRec: {s} at ({}) {s} at ({}, {})", .{ @tagName(word_direction), word_idx, @tagName(direction), start[0], start[1] });
    if (word_idx < 0 or word_idx >= word.len) {
        //log.info("word out of bounds -> successful", .{});
        return .{ .found = 0 };
    }
    if (!grid.inBounds(start[0], start[1])) {
        //log.info("Coordinate out of bound -> unsuccessful", .{});
        return .not_found;
    }

    const incx, const incy = comptime incFromDirection(direction);
    const word_inc = comptime wordIncFromScanDir(word_direction);

    if (grid.get(start[0], start[1]) != word[@intCast(word_idx)]) {
        //log.info("{c} != {c}", .{ grid.get(start[0], start[1]), word[@intCast(word_idx)] });
        return .not_found;
    }
    //log.info("Found {c}", .{word[@intCast(word_idx)]});

    const ret = searchWordRec(
        grid,
        word,
        word_idx + word_inc,
        word_direction,
        .{ start[0] + incx, start[1] + incy },
        direction,
    );

    return switch (ret) {
        .found => |count| .{ .found = count + 1 },
        .not_found => .not_found,
    };
}

fn LetterContainedInWord(comptime word: []const u8, letter: u8) ?usize {
    inline for (word, 0..) |cletter, i| {
        if (cletter == letter) return i;
    }
    return null;
}

const Grid = struct {
    height: isize,
    width: isize,
    data: std.ArrayList(u8),
    mark_data: std.ArrayList(Flags),

    pub inline fn get(self: *const Grid, x: isize, y: isize) u8 {
        assert(x >= 0);
        assert(x < self.width);
        assert(y >= 0);
        assert(y < self.height);
        return self.data.items[@intCast(self.idxFromXY(x, y))];
    }

    pub inline fn flagsMut(self: *const Grid, x: isize, y: isize) *Flags {
        assert(x >= 0);
        assert(x < self.width);
        assert(y >= 0);
        assert(y < self.height);
        return &self.mark_data.items[self.idxFromXY(x, y)];
    }

    pub inline fn xFromIdx(self: *const Grid, idx: isize) isize {
        assert(idx < self.data.items.len);
        return @intCast(@as(usize, @intCast(idx)) % @as(usize, @intCast(self.width)));
    }
    pub inline fn yFromIdx(self: *const Grid, idx: isize) isize {
        assert(idx < self.data.items.len);
        return @intCast(@as(usize, @intCast(idx)) / @as(usize, @intCast(self.width)));
    }
    pub inline fn idxFromXY(self: *const Grid, x: isize, y: isize) usize {
        assert(x >= 0);
        assert(x < self.width);
        assert(y >= 0);
        assert(y < self.height);
        return @intCast((self.width * y) + x);
    }

    pub inline fn xyFromIdx(self: *const Grid, idx: isize) struct { isize, isize } {
        assert(idx < self.data.items.len);
        return .{ self.xFromIdx(idx), self.yFromIdx(idx) };
    }

    pub inline fn inBounds(self: *const Grid, x: isize, y: isize) bool {
        return x < self.width and x >= 0 and y < self.height and y >= 0;
    }

    pub const Flags = struct {
        is_word: bool = false,
        direction: ?Direction = null,
    };
};

const Direction = enum(u3) {
    up,
    upright,
    right,
    downright,
    down,
    downleft,
    left,
    upleft,

    pub fn negate(self: Direction) Direction {
        return switch (self) {
            .up => .down,
            .upright => .downleft,
            .right => .left,
            .downright => .upleft,
            .down => .up,
            .downleft => .upright,
            .left => .right,
            .upleft => .downright,
        };
    }
};

const ScanDir = enum {
    forward,
    backward,

    pub fn negate(self: ScanDir) ScanDir {
        return switch (self) {
            .forward => .backward,
            .backward => .forward,
        };
    }
};

fn incFromDirection(direction: Direction) struct { isize, isize } {
    return switch (direction) {
        inline .up => .{ 0, -1 },
        inline .upright => .{ 1, -1 },
        inline .right => .{ 1, 0 },
        inline .downright => .{ 1, 1 },
        inline .down => .{ 0, 1 },
        inline .downleft => .{ -1, 1 },
        inline .left => .{ -1, 0 },
        inline .upleft => .{ -1, -1 },
    };
}

fn wordIncFromScanDir(word_direction: ScanDir) isize {
    return switch (word_direction) {
        inline .forward => 1,
        inline .backward => -1,
    };
}
