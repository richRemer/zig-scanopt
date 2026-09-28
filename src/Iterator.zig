const std = @import("std");
const mem = std.mem;
const Args = std.process.Args;
const Iterator = @This();

args: []const []const u8,
argi: usize = 0,
opti: usize = 0,
term: bool = false,
optbuf: [2]u8,

pub fn init(args: []const []const u8) Iterator {
    return .{
        .args = args,
        .optbuf = undefined,
    };
}

pub fn next(this: *Iterator) ?[]const u8 {
    if (this.argi >= this.args.len) {
        return null;
    }

    const arg = this.args[this.argi];

    if (mem.eql(u8, arg, "--")) {
        this.term = true;
    }

    if (this.term) {
        this.argi +%= 1;
        return arg;
    } else if (long(arg)) {
        if (this.opti > 0) {
            const vali = this.opti +% 1; // one past '='
            this.argi +%= 1;
            this.opti = 0;
            return arg[vali..];
        } else if (mem.findScalarPos(u8, arg, 3, '=')) |opti| {
            this.opti = opti;
            return arg[0..opti];
        } else {
            this.argi +%= 1;
            return arg;
        }
    } else if (short(arg)) {
        if (this.opti == 0) this.opti = 1;

        this.optbuf[0] = '-';
        this.optbuf[1] = arg[this.opti];
        this.opti +%= 1;

        if (this.opti >= arg.len) {
            this.argi +%= 1;
            this.opti = 0;
        }

        return @as([]const u8, this.optbuf[0..2]);
    } else {
        this.argi +%= 1;
        return arg;
    }
}

pub fn nextval(this: *Iterator) ?[]const u8 {
    if (this.argi >= this.args.len) {
        return null;
    }

    const arg = this.args[this.argi];

    if (long(arg)) {
        if (this.opti == 0) {
            return null;
        } else {
            const vali = this.opti + 1;
            this.argi +%= 1;
            this.opti = 0;
            return arg[vali..];
        }
    } else if (short(arg)) {
        if (this.opti == 0) {
            return null;
        } else {
            const vali = this.opti;
            this.argi +%= 1;
            this.opti = 0;
            return arg[vali..];
        }
    } else {
        this.argi +%= 1;
        return arg;
    }
}

fn long(arg: []const u8) bool {
    if (arg.len < 3) return false;
    if (!mem.startsWith(u8, arg, "--")) return false;
    return valid(arg[2]);
}

fn short(arg: []const u8) bool {
    if (arg.len < 2) return false;
    if (!mem.startsWith(u8, arg, "-")) return false;
    return valid(arg[1]);
}

fn valid(ch: u8) bool {
    return switch (ch) {
        0x30...0x39 => true,
        0x41...0x5A => true,
        0x61...0x7A => true,
        else => false,
    };
}

test "iterate over non-option args" {
    const testing = std.testing;

    var it = Iterator.init(&.{
        "foo",
        "bar",
        "baz",
    });

    try testing.expectEqualStrings("foo", it.next().?);
    try testing.expectEqualStrings("bar", it.next().?);
    try testing.expectEqualStrings("baz", it.next().?);
    try testing.expectEqual(null, it.next());
}

test "iterate over POSIX-style options" {
    const testing = std.testing;

    var it = Iterator.init(&.{
        "-x",
        "-if",
        "-vfx",
        "--",
        "-opts",
    });

    try testing.expectEqualStrings("-x", it.next().?);
    try testing.expectEqual(null, it.nextval());
    try testing.expectEqualStrings("-i", it.next().?);
    try testing.expectEqualStrings("-f", it.next().?);
    try testing.expectEqualStrings("-v", it.next().?);
    try testing.expectEqualStrings("fx", it.nextval().?);
    try testing.expectEqualStrings("--", it.next().?);
    try testing.expectEqualStrings("-opts", it.next().?);
    try testing.expectEqual(null, it.next());
}

test "iterate over GNU-style options" {
    const testing = std.testing;

    var it = Iterator.init(&.{
        "--foo",
        "--foo=bar",
        "--foo=",
        "--",
        "--foo=bar",
    });

    try testing.expectEqualStrings("--foo", it.next().?);
    try testing.expectEqual(null, it.nextval());
    try testing.expectEqualStrings("--foo", it.next().?);
    try testing.expectEqualStrings("bar", it.nextval().?);
    try testing.expectEqualStrings("--foo", it.next().?);
    try testing.expectEqualStrings("", it.next().?);
    try testing.expectEqualStrings("--", it.next().?);
    try testing.expectEqualStrings("--foo=bar", it.next().?);
    try testing.expectEqual(null, it.next());
}
