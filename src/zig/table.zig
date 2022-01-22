const std = @import("std");
const assert = std.debug.assert;

const Symbol = struct {
    index: u8,
    data: []const u8,
};

const HIGH_BIT = 1 << 7;
const PREFIX = [4]u8{ 'M' | HIGH_BIT, 'I' | HIGH_BIT, 'N' | HIGH_BIT, 'Z' | HIGH_BIT };
pub const MAX_SYMBOL = 8;

pub const Table = struct {
    n: u8 = 0,
    lengths: [255]u8,
    symbols: [255][MAX_SYMBOL]u8,
    index: [257]u8,

    pub fn init() Table {
        return .{
            .lengths = std.mem.zeroes([255]u8),
            .symbols = std.mem.zeroes([255][MAX_SYMBOL]u8),
            .index = std.mem.zeroes([257]u8),
        };
    }

    /// insert adds a new entry into the table. It's up to the caller to ensure that:
    /// 1. `insert` must be ordered by the first character. You can't insert "world" before "hello".
    /// 2. The longest prefix must be inserted first. You can't insert "he" before "hello".
    pub fn insert(self: *Table, data: []const u8) void {
        assert(data.len > 0 and data.len <= MAX_SYMBOL);
        const idx = self.n;
        self.n += 1;
        self.lengths[idx] = @intCast(u8, data.len);
        std.mem.copy(u8, &self.symbols[idx], data);
    }

    /// buildIndex builds the index used for encoding. This must be called after all `insert`
    /// have been done in order for `findLongestSymbol` to work as intended.
    pub fn buildIndex(self: *Table) void {
        var idx: u8 = 0;
        var current_fst: usize = 0;

        while (idx < 255) : (idx += 1) {
            if (self.lengths[idx] == 0) {
                break;
            }

            const fst = self.symbols[idx][0];
            while (current_fst <= fst) : (current_fst += 1) {
                self.index[current_fst] = idx;
            }
        }

        while (current_fst <= 256) : (current_fst += 1) {
            self.index[current_fst] = idx;
        }
    }

    pub fn lookup(self: *const Table, idx: u8) []const u8 {
        return self.symbols[idx][0..self.lengths[idx]];
    }

    pub fn findLongestSymbol(self: *const Table, data: []const u8) ?Symbol {
        const fst = @as(usize, data[0]);
        var idx = self.index[fst];
        var idx_stop = self.index[fst + 1];
        while (idx < idx_stop) : (idx += 1) {
            const sym = self.lookup(idx);
            if (std.mem.startsWith(u8, data, sym)) {
                return Symbol{
                    .index = idx,
                    .data = sym,
                };
            }
        }
        return null;
    }

    pub fn findLongestMultiSymbol(self: *const Table, data: []const u8) ?Symbol {
        if (self.findLongestSymbol(data)) |sym| {
            if (sym.data.len > 1) return sym;
        }
        return null;
    }

    pub fn writeTo(self: *const Table, writer: anytype) !void {
        try writer.writeAll(&PREFIX);
        try writer.writeByte(1);
        try writer.writeByte(self.n);
        try writer.writeAll(self.lengths[0..self.n]);
        const bin_symbols = @ptrCast([*]const u8, &self.symbols);
        try writer.writeAll(bin_symbols[0 .. self.n * MAX_SYMBOL]);
    }

    pub fn readFrom(reader: anytype) !Table {
        var res = Table.init();

        const prefix = try reader.readBytesNoEof(PREFIX.len);
        if (!std.mem.eql(u8, &PREFIX, &prefix)) return error.InvalidFormat;

        const version = try reader.readByte();
        if (version != 1) return error.InvalidFormat;

        const n = try reader.readByte();
        try reader.readNoEof(res.lengths[0..n]);

        const bin_symbols = @ptrCast([*]u8, &res.symbols);
        try reader.readNoEof(bin_symbols[0 .. n * MAX_SYMBOL]);

        res.n = n;
        res.buildIndex();
        return res;
    }
};

const testing = std.testing;

test "set and lookup" {
    var tbl = Table.init();
    tbl.insert("hello");
    tbl.insert("world");

    try testing.expectEqualSlices(u8, "hello", tbl.lookup(0));
    try testing.expectEqualSlices(u8, "world", tbl.lookup(1));
    try testing.expectEqualSlices(u8, "", tbl.lookup(2));
}

test "serialization" {
    var tbl = Table.init();
    tbl.insert("hello");
    tbl.insert("world");

    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    try tbl.writeTo(buf.writer());
    // Prefix, version, n, (lengths + symbols) * 2 entries.
    try testing.expectEqual(@as(usize, 4 + 1 + 1 + (1 + MAX_SYMBOL) * 2), buf.items.len);

    var fbs = std.io.fixedBufferStream(buf.items);
    var tbl2 = try Table.readFrom(fbs.reader());
    try testing.expectEqualSlices(u8, "hello", tbl2.lookup(0));
    try testing.expectEqualSlices(u8, "world", tbl2.lookup(1));
    try testing.expectEqualSlices(u8, "", tbl2.lookup(2));
}
