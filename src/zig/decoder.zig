const std = @import("std");
const Table = @import("./table.zig").Table;

pub fn decode(writer: *std.Io.Writer, data: []const u8, table: *const Table) !void {
    var i: usize = 0;
    while (i < data.len) {
        if (data[i] == 255) {
            try writer.writeByte(data[i + 1]);
            i += 2;
        } else {
            try writer.writeAll(table.lookup(data[i]));
            i += 1;
        }
    }
}

const testing = std.testing;

test "decoding" {
    var tbl = Table.init();
    tbl.insert("hello");
    tbl.insert("world");
    const data = [_]u8{ 0, 255, ' ', 1 };

    var output: [100]u8 = undefined;
    var w = std.Io.Writer.fixed(&output);
    try decode(&w, &data, &tbl);

    try testing.expectEqualSlices(u8, "hello world", w.buffered());
}
