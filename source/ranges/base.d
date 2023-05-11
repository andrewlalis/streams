module ranges.base;

import ranges.array;

import std.traits;

/** 
 * A base class for anything that we can read some bytes from.
 */
abstract class ReadableRange {
    abstract int read(ref ubyte[] buffer, uint offset, uint length);

    int read(ref ubyte[] buffer, uint offset) {
        if (buffer.length < 1) return 0;
        if (offset >= buffer.length) return -1;
        return read(buffer, offset, cast(uint) buffer.length - offset);
    }

    int read(ref ubyte[] buffer) {
        if (buffer.length < 1) return 0;
        return read(buffer, 0, cast(uint) buffer.length);
    }

    int read(T)(ref T buffer, uint offset, uint length) if (isStaticArray!T) {
        if (buffer.length < 1) return 0;
        ubyte[] data = buffer[];
        return read(data, offset, length);
    }

    int read(T)(ref T buffer, uint offset) if (isStaticArray!T) {
        return read(buffer, offset, buffer.length - offset);
    }

    int read(T)(ref T buffer) if (isStaticArray!T) {
        return read(buffer, 0, buffer.length);
    }
}

/** 
 * A buffered version of the ReadableRange that's compatible with the D
 * standard library's concept of an InputRange.
 */
struct BufferedReadableRange {
    public static immutable uint DEFAULT_BUFFER_SIZE = 8192;

    private ReadableRange range;
    private ubyte[] buffer;
    private uint lastReadCount;
    private bool finished;

    this(ReadableRange range, ubyte[] buffer) {
        this.range = range;
        this.buffer = buffer;
        this.lastReadCount = 0;
        this.finished = false;
        this.popFront(); // Pop-front once to load the buffer with the first bit of data.
    }

    this(ReadableRange range) {
        this(range, new ubyte[DEFAULT_BUFFER_SIZE]);
    }

    void popFront() {
        if (this.finished) return;
        this.lastReadCount = this.range.read(buffer);
        if (this.lastReadCount == -1) {
            throw new Exception("Reading failed.");
        } else if (this.lastReadCount == 0) {
            this.finished = true;
        }
    }

    ubyte[] front() {
        return this.buffer[0 .. lastReadCount];
    }

    bool empty() {
        return this.finished;
    }
}

unittest {
    import std.range.primitives;
    import ranges.array;
    assert(isInputRange!BufferedReadableRange);
    auto r = BufferedReadableRange(new ByteArrayInputRange([1, 2, 3]));
    assert(!r.empty());
    assert(r.front() == [1, 2, 3]);
    r.popFront();
    assert(r.empty());
    assert(r.front() == []);
    r.popFront();
}

BufferedReadableRange asInputRange(ReadableRange range, uint bufferSize = BufferedReadableRange.DEFAULT_BUFFER_SIZE) {
    ubyte[] buffer = new ubyte[bufferSize];
    return BufferedReadableRange(range, buffer);
}

/** 
 * A base class for anything that we can write some bytes to.
 */
abstract class WritableRange {
    /** 
     * Writes bytes to this range.
     * Params:
     *   buffer = The buffer containing data to write.
     *   offset = The offset in the buffer to start writing from.
     *   length = The number of bytes to write.
     * Returns: The number of bytes that were written, or -1 in case of error.
     */
    abstract int write(ref ubyte[] buffer, uint offset, uint length);

    /** 
     * Writes bytes to this range.
     * Params:
     *   buffer = The buffer containing data to write.
     *   offset = The offset in the buffer to start writing from.
     * Returns: The number of bytes that were written, or -1 in case of error.
     */
    int write(ref ubyte[] buffer, uint offset) {
        if (buffer.length < 1) return 0;
        if (offset >= buffer.length) return -1;
        return write(buffer, offset, cast(uint) buffer.length - offset);
    }

    /** 
     * Writes bytes to this range.
     * Params:
     *   buffer = The buffer containing data to write.
     * Returns: The number of bytes that were written, or -1 in case of error.
     */
    int write(ref ubyte[] buffer) {
        if (buffer.length < 1) return 0;
        return write(buffer, 0, cast(uint) buffer.length);
    }

    /** 
     * Writes bytes to this range, using the standard OutputRange "put" method
     * for compatibility with D's OutputRanges. Throws an exception if not all
     * bytes could be written.
     * Params:
     *   buffer = The buffer containing data to write.
     */
    void put(ref ubyte[] buffer) {
        if (this.write(buffer) != buffer.length) {
            throw new Exception("Failed to write.");
        }
    }
}

unittest {
    import std.range.primitives;
    assert(isOutputRange!(WritableRange, ubyte[]));
}

/** 
 * An interface for any resource that's closeable, like files, sockets, pipes,
 * and so on.
 */
interface ClosableRange {
    void close();
}
