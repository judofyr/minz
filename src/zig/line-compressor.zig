const std = @import("std");
const minz = @import("main.zig");

const allocator = std.heap.c_allocator;

pub fn main() !void {
    var args = std.process.args();
    const binary_name = try args.next(allocator) orelse unreachable;
    defer allocator.free(binary_name);

    const file_name = try args.next(allocator) orelse {
        std.debug.print("usage: {s} FILENAME\n", .{binary_name});
        std.process.exit(0);
    };
    defer allocator.free(file_name);

    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();

    std.debug.print("Reading file: {s}\n", .{file_name});

    var file = try std.fs.cwd().openFile(file_name, .{});
    try file.reader().readAllArrayList(&data, 500_000_000);

    var n: usize = 0;
    var lines = std.mem.split(u8, data.items, "\n");
    while (lines.next()) |line| {
        _ = line;
        n += 1;
    }

    std.debug.print("Read {} lines.\n", .{n});

    var tbl = minz.Table.init();

    var iter: usize = 1;
    const num_iter = 10;
    while (iter <= num_iter) : (iter += 1) {
        std.debug.print("Training on iteration {}\n", .{iter});

        std.debug.print("Adding 1% of lines...\n", .{});
        var t = minz.Trainer.init(&tbl);
        var i: usize = 0;
        lines = std.mem.split(u8, data.items, "\n");
        while (lines.next()) |line| {
            if (i % 100 == 0) {
                t.add(line);
            }
            i += 1;
        }
        std.debug.print("Building new table.\n", .{});
        tbl = try t.build(allocator);
    }

    var uncompressed_size: usize = 0;
    var compressed_size: usize = 0;
    std.debug.print("Compressing...\n", .{});

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    lines = std.mem.split(u8, data.items, "\n");
    while (lines.next()) |line| {
        uncompressed_size += line.len;
        try minz.encode(buf.writer(), line, &tbl);
        compressed_size += buf.items.len;
        buf.clearRetainingCapacity();
    }

    std.debug.print("Uncompressed: {}\nCompressed:   {}\n", .{ uncompressed_size, compressed_size });
    std.debug.print("Ratio: {d}\n", .{@intToFloat(f64, uncompressed_size) / @intToFloat(f64, compressed_size)});
}
