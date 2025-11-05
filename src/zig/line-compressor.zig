const std = @import("std");
const minz = @import("main.zig");

const allocator = std.heap.c_allocator;

pub fn main() !void {
    var args = std.process.args();
    const binary_name = args.next() orelse unreachable;

    const file_name = args.next() orelse {
        std.debug.print("usage: {s} FILENAME\n", .{binary_name});
        std.process.exit(0);
    };

    var threaded: std.Io.Threaded = .init(allocator);
    defer threaded.deinit();

    std.debug.print("Reading file: {s}\n", .{file_name});

    var file = try std.fs.cwd().openFile(file_name, .{});

    var buf: [1024]u8 = undefined;
    var r = file.reader(threaded.io(), &buf);
    const data = try r.interface.allocRemaining(allocator, .unlimited);
    defer allocator.free(data);

    var n: usize = 0;
    var lines = std.mem.splitAny(u8, data, "\n");
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
        lines = std.mem.splitAny(u8, data, "\n");
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

    var result = std.Io.Writer.Allocating.init(allocator);
    defer result.deinit();

    lines = std.mem.splitAny(u8, data, "\n");
    while (lines.next()) |line| {
        uncompressed_size += line.len;
        try minz.encode(&result.writer, line, &tbl);
        compressed_size += result.written().len;
        result.shrinkRetainingCapacity(0);
    }

    std.debug.print("Uncompressed: {}\nCompressed:   {}\n", .{ uncompressed_size, compressed_size });
    std.debug.print("Ratio: {d}\n", .{@as(f64, @floatFromInt(uncompressed_size)) / @as(f64, @floatFromInt(compressed_size))});
}
