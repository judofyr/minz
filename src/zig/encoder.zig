const std = @import("std");
const Table = @import("./table.zig").Table;

pub fn encode(writer: *std.Io.Writer, data: []const u8, tbl: *const Table) !void {
    var i: usize = 0;
    while (i < data.len) {
        if (tbl.findLongestSymbol(data[i..])) |sym| {
            try writer.writeByte(sym.index);
            i += sym.data.len;
        } else {
            try writer.writeByte(255);
            try writer.writeByte(data[i]);
            i += 1;
        }
    }
}

const testing = std.testing;

test "encode" {
    var tbl = Table.init();
    tbl.insert("hallo");
    tbl.insert("hello");
    tbl.insert("world");
    tbl.buildIndex();

    const data = "hello worldz";

    var output: [100]u8 = undefined;
    var w = std.Io.Writer.fixed(&output);
    try encode(&w, data, &tbl);

    try testing.expectEqualSlices(u8, &[_]u8{ 1, 255, ' ', 2, 255, 'z' }, w.buffered());
}
