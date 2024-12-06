const std = @import("std");
const mem = std.mem;
const log = std.log;
const assert = std.debug.assert;
const util = @import("util");

pub const std_options = std.Options{
    // Set the log level to info
    .log_level = .info,

    // Define logFn to override the std implementation
    //.logFn = log.defaultLog,
};

const logging = false;

const input_path = "03/input1";

pub fn main() !void {
    std.debug.print("Day 03\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const input = try std.fs.cwd().readFileAlloc(allocator, input_path, 1 << 32);

    var buf: [3]u8 = undefined;

    var timer = try std.time.Timer.start();

    var state: enum {
        none,
        m,
        mu,
        mul,
        mul_pl,
        nr0,
        comma,
        nr1,

        d,
        do,
        don,
        don_tick,
        don_tick_t,

        don_tick_t_pl,
        do_pl,
    } = .none;

    var sum: i64 = 0;

    var nr0: i64 = 0;
    var nr1: i64 = 0;
    var enable = true;

    var pos: usize = 0;

    while_loop: while (pos < input.len) : (pos += 1) {
        if (logging) log.info("[{}] state: {s} [{s}] [{c}]", .{
            pos,
            @tagName(state),
            if (enable) "enable" else "disable",
            input[pos],
        });
        switch (state) {
            .none => switch (input[pos]) {
                'm' => state = .m,
                'd' => state = .d,
                else => continue :while_loop,
            },
            .m => switch (input[pos]) {
                'u' => state = .mu,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .mu => switch (input[pos]) {
                'l' => state = .mul,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .mul => switch (input[pos]) {
                '(' => state = .mul_pl,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .mul_pl => {
                for (0..(buf.len + 1)) |i| {
                    switch (input[pos + i]) {
                        '0'...'9' => |c| buf[i] = c,
                        else => {
                            if (i == 0) {
                                state = .none;
                                continue :while_loop;
                            }
                            pos += i - 1;
                            nr0 = try std.fmt.parseUnsigned(i64, buf[0..i], 10);
                            state = .nr0;
                            continue :while_loop;
                        },
                    }
                }
                unreachable;
            },
            .nr0 => switch (input[pos]) {
                ',' => state = .comma,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .comma => {
                for (0..(buf.len + 1)) |i| {
                    switch (input[pos + i]) {
                        '0'...'9' => |c| buf[i] = c,
                        else => {
                            if (i == 0) {
                                state = .none;
                                continue :while_loop;
                            }
                            pos += i - 1;
                            nr1 = try std.fmt.parseUnsigned(i64, buf[0..i], 10);
                            state = .nr1;
                            continue :while_loop;
                        },
                    }
                }
                unreachable;
            },
            .nr1 => switch (input[pos]) {
                ')' => {
                    if (enable) {
                        sum += nr0 * nr1;
                    }
                    nr0 = 0;
                    nr1 = 0;
                    state = .none;
                    continue :while_loop;
                },
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },

            .d => switch (input[pos]) {
                'o' => state = .do,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .do => switch (input[pos]) {
                'n' => state = .don,
                '(' => state = .do_pl,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .don => switch (input[pos]) {
                '\'' => state = .don_tick,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .don_tick => switch (input[pos]) {
                't' => state = .don_tick_t,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .don_tick_t => switch (input[pos]) {
                '(' => state = .don_tick_t_pl,
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },

            .don_tick_t_pl => switch (input[pos]) {
                ')' => {
                    enable = false;
                    state = .none;
                    continue :while_loop;
                },
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
            .do_pl => switch (input[pos]) {
                ')' => {
                    enable = true;
                    state = .none;
                    continue :while_loop;
                },
                else => {
                    state = .none;
                    continue :while_loop;
                },
            },
        }
    }

    const needed = timer.lap();
    util.reportTime(needed);
    log.info("sum: {}", .{sum});
}
