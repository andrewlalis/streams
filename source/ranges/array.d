module ranges.array;

import ranges.base;

class ByteArrayInputRange : ReadableRange {
    private ubyte[] source;
    private uint currentIndex;

    this(ubyte[] source) {
        this.source = source;
        this.currentIndex = 0;
    }

    override int read(ref ubyte[] buffer, uint offset, uint length) {
        if (this.currentIndex >= this.source.length || buffer.length < 1) {
            return 0;
        }
        if (offset + length > buffer.length) {
            return -1;
        }
        uint lengthToRead = cast(uint) this.source.length - this.currentIndex;
        if (lengthToRead > length) lengthToRead = length;
        buffer[offset .. offset + lengthToRead] = this.source[this.currentIndex .. this.currentIndex + lengthToRead];
        this.currentIndex += lengthToRead;
        return lengthToRead;
    }
}

unittest {
    ReadableRange r = new ByteArrayInputRange([1, 2, 3]);
    ubyte[] buffer = new ubyte[5];
    int result = r.read(buffer);
    assert(result == 3);
    assert(buffer == [1, 2, 3, 0, 0]);
}

class ByteArrayOutputRange : WritableRange {
    import std.array : Appender, appender;

    private Appender!(ubyte[]) byteAppender;

    this() {
        this.byteAppender = appender!(ubyte[])();
    }

    override int write(ref ubyte[] buffer, uint offset, uint length) {
        if (buffer.length < 1) {
            return 0;
        }
        if (offset + length > buffer.length) {
            return -1;
        }
        this.byteAppender ~= buffer[offset .. offset + length];
        return length;
    }

    ubyte[] toArray() {
        return this.byteAppender[];
    }
}

unittest {
    WritableRange r = new ByteArrayOutputRange();
    ubyte[] buffer = [1, 2, 3];
    r.write(buffer);
    buffer = [4, 5, 6];
    r.write(buffer);
    assert((cast(ByteArrayOutputRange)r).toArray() == [1, 2, 3, 4, 5, 6]);
}
