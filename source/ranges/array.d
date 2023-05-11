module ranges.array;

import ranges.base;

/** 
 * A readable range that reads from a byte array.
 */
class ByteArrayInputRange : ReadableRange {
    private ubyte[] source;
    private uint currentIndex;

    this(ubyte[] source) {
        this.source = source;
        this.currentIndex = 0;
    }

    alias read = ReadableRange.read;

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
    auto r = new ByteArrayInputRange([1, 2, 3]);
    ubyte[] buffer = new ubyte[5];
    int result = r.read(buffer);
    assert(result == 3);
    assert(buffer == [1, 2, 3, 0, 0]);

    r = new ByteArrayInputRange([1, 2, 3, 4, 5, 6, 7, 8, 9]);
    ubyte[2] fixedBuffer;
    result = r.read(fixedBuffer);
    assert(result == 2);
    assert(fixedBuffer == [1, 2]);
    result = r.read(fixedBuffer);
    assert(result == 2);
    assert(fixedBuffer == [3, 4]);
    r.read(fixedBuffer); // 5, 6
    r.read(fixedBuffer); // 7, 8
    result = r.read(fixedBuffer);
    assert(result == 1);
    assert(fixedBuffer == [9, 8]); // 8 is left over from the last read.
}

/** 
 * A writable range that writes to an array appender, so that the resulting
 * array is obtainable via `toArray()`.
 */
class ByteArrayOutputRange : WritableRange {
    import std.array : Appender, appender;

    private Appender!(ubyte[]) byteAppender;

    this() {
        this.byteAppender = appender!(ubyte[])();
    }

    alias write = WritableRange.write;

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
    auto r = new ByteArrayOutputRange();
    ubyte[] buffer = [1, 2, 3];
    r.write(buffer);
    buffer = [4, 5, 6];
    r.write(buffer);
    assert(r.toArray() == [1, 2, 3, 4, 5, 6]);
}
