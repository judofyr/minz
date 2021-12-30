const std = @import("std");
const assert = std.debug.assert;

const Symbol = struct {
    index: u8,
    data: []const u8,
};

pub const Table = struct {
    n: u8 = 0,
    lengths: [255]u8,
    symbols: [255][8]u8,
    index: [257]u8,

    pub fn init() Table {
        return .{
            .lengths = std.mem.zeroes([255]u8),
            .symbols = std.mem.zeroes([255][8]u8),
            .index = std.mem.zeroes([257]u8),
        };
    }

    /// insert adds a new entry into the table. It's up to the caller to ensure that:
    /// 1. `insert` must be ordered by the first character. You can't insert "world" before "hello".
    /// 2. The longest prefix must be inserted first. You can't insert "he" before "hello".
    pub fn insert(self: *Table, data: []const u8) void {
        assert(data.len > 0 and data.len <= 8);
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
