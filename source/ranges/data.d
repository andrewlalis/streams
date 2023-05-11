module ranges.data;

import ranges.base;
import ranges.filter;

class DataInputRange : FilteredReadableRange {
    this(ReadableRange range) {
        super(range);
    }

    int readInt() {
        union U { int n; ubyte[4] bytes; }
        U u;
        int bytesRead = this.range.read(u.bytes, 0, 4);
        if (bytesRead != 4) throw new Exception("Oh no!");
        return u.n;
    }
}

unittest {
    import ranges;
    import std.stdio;
    DataInputRange dIn = new DataInputRange(new ByteArrayInputRange([0, 0, 0, 0]));
    writeln(dIn.readInt());
}
