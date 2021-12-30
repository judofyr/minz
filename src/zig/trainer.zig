const std = @import("std");

const encode = @import("./encoder.zig").encode;
const Table = @import("table.zig").Table;

pub const Trainer = struct {
    const Cand = struct {
        data: [8]u8,
        len: u8,
        gain: usize,

        fn slice(cand: *const @This()) []const u8 {
            return cand.data[0..cand.len];
        }
    };

    // Note that the trainer uses a "code" which is a number between 0 and 512.
    // When this is between 0-255 it refers to a single byte.
    // When this is between 256-512 it refers to a symbol in the table.

    table: *const Table,
    count1: [512]usize,
    count2: [512][512]usize,

    pub fn init(table: *const Table) Trainer {
        return Trainer{
            .table = table,
            .count1 = std.mem.zeroes([512]usize),
            .count2 = std.mem.zeroes([512][512]usize),
        };
    }

    pub fn deinit(self: *Trainer) void {
        self.* = undefined;
    }

    pub fn add(self: *Trainer, text: []const u8) void {
        var pos: usize = 0;
        var prev: ?usize = null;

        while (pos < text.len) {
            const byte_idx = @as(usize, text[pos]);
            self.count1[byte_idx] += 1;
            if (prev) |p| self.count2[p][byte_idx] += 1;

            if (self.table.findLongestSymbol(text[pos..])) |sym| {
                const sym_idx = 256 + @as(usize, sym.index);

                self.count1[sym_idx] += 1;
                if (prev) |p| self.count2[p][sym_idx] += 1;

                pos += sym.data.len;
                prev = sym_idx;
            } else {
                pos += 1;
                prev = byte_idx;
            }
        }
    }

    fn decode(self: *const Trainer, code: usize, buf: *[8]u8, i: *u8) void {
        if (code < 256) {
            buf[i.*] = @intCast(u8, code);
            i.* += 1;
        } else {
            const d = self.table.lookup(@intCast(u8, code - 256));
            const len = @minimum(@intCast(u8, d.len), 8 - i.*);
            std.mem.copy(u8, buf[i.*..], d[0..len]);
            i.* += len;
        }
    }

    pub fn build(self: *const Trainer, allocator: std.mem.Allocator) !Table {
        var cands = std.ArrayList(Cand).init(allocator);
        defer cands.deinit();

        // The number of entries in the table.
        const m: usize = 256 + @as(usize, self.table.n);

        var code1: usize = 0;
        while (code1 < m) : (code1 += 1) {
            var cand: [8]u8 = undefined;
            var i: u8 = 0;

            self.decode(code1, &cand, &i);

            if (self.count1[code1] > 0) {
                var gain1 = i * self.count1[code1];
                try cands.append(Cand{ .data = cand, .len = i, .gain = gain1 });
            }

            // If the first symbol is already of length 8 there's nothing to combine.
            if (i == 8) continue;

            var code2: usize = 0;
            while (code2 < m) : (code2 += 1) {
                var j = i;
                self.decode(code2, &cand, &j);

                if (self.count2[code1][code2] > 0) {
                    var gain2 = j * self.count2[code1][code2];
                    try cands.append(Cand{ .data = cand, .len = j, .gain = gain2 });
                }
            }
        }

        const sorting = struct {
            fn byGain(context: void, a: Cand, b: Cand) bool {
                _ = context;
                return a.gain > b.gain;
            }

            fn byData(context: void, a: Cand, b: Cand) bool {
                _ = context;
                return switch (std.math.order(a.data[0], b.data[0])) {
                    .lt => true,
                    .gt => false,
                    .eq => std.mem.lessThan(u8, b.slice(), a.slice()),
                };
            }
        };

        if (cands.items.len > 255) {
            // Only keep the 255 best candidates (by gain).
            std.sort.sort(Cand, cands.items, {}, sorting.byGain);
            cands.shrinkRetainingCapacity(255);
        }

        std.sort.sort(Cand, cands.items, {}, sorting.byData);

        var res = Table.init();
        for (cands.items) |cand| {
            res.insert(cand.slice());
        }
        res.buildIndex();
        return res;
    }
};

const testing = std.testing;

test "training" {
    const target = "tumcwitumvldb";
    const expected_compression = [_]usize{ 26, 7, 4, 2 };

    var tbl = Table.init();

    for (expected_compression) |c| {
        var compressed: [100]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&compressed);
        try encode(fbs.writer(), target, &tbl);
        try testing.expectEqual(c, fbs.getWritten().len);

        var t = Trainer.init(&tbl);
        defer t.deinit();
        t.add(target);
        tbl = try t.build(testing.allocator);
    }
}
