# minz: A minimal compressor

minz is a minimal string compressor based on the paper [FSST: Fast Random Access String Compression](http://www.vldb.org/pvldb/vol13/p2649-boncz.pdf).

The compressed format is very simple:
It uses a pre-computed dictionary of 255 entries, each word being at most 8 bytes long.
Bytes 0x00 to 0xFE adds a word from the dictionary, while byte 0xFF is an escape character which adds the next character as-is.

**Example:** If the dictionary contains `0x00 = hello` and `0x01 = world`,
then `0x00 0xFF 0x20 0x01 0xFF 0x21` (six bytes) decompresses into `hello world!`.

This has the following characteristics:

* You'll have to build the dictionary on sample data before you can compress anything.
* There's extremely little overhead in the compressed string. 
  This makes it usable for compressing small strings (<200 bytes) directly.
* The maximal compression ratio is 8x (since each word in the dictionary is at most 8 bytes long), but typical ratio seems to be around ~2x-3x.
* This makes minz quite different from "classical" compression algorithms and it has different use cases.
  In a database system you can use minz to compress the individual _entries_ in an index,
  while with other compression schemes you typically have to compress a bigger block.
  This is what the authors of the paper mean by "random access string compression".

## Usage

minz is currently provided as a **library in Zig**.
There's no documentation and you'll have to look at the public functions and test cases.

There's also a small command-line tool which reads in a file, trains a dictionary (from 1% of the lines), compresses each line separately, and then reports the total ratio:

```
$ zig build
$ ./zig-out/bin/line-compressor access.log
Reading file: access.log
Read 689253 lines.
Training...
Compressing...
Uncompressed: 135114557
Compressed:   46209436
Ratio: 2.9239603140795745
```

## Current status

This is just a learning project for me to personally learn the algorithm in the paper.
It's not being used in any production systems, and I'm not actively developing it.

In addition, the dictionary-training algorithm presented in the paper is actually a bit vague on the exact details.
There is some choice in how you combine symbols and right now it doesn't seem to create an "optimal" dictionary according to human inspection.
If you intend to use this for a "real" project you'll probably have to invest some more time.

## Roadmap / pending work

- [ ] Improve training algorithm.
- [ ] Command-line tool (for training/encoding/decoding).
- [ ] Plain JavaScript encoder/decoder.
- [ ] Optimized encoder using AVX512.
- [ ] Integrate encoder/decoder as a native Node module.