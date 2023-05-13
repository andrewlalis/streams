/** 
 * A collection of array-backed streams for in-memory reading and writing.
 */
module streams.types.array;

/** 
 * An input stream that reads from an array of items.
 */
struct ArrayInputStream(DataType) {
    private DataType[] array;
    private uint currentIndex = 0;

    int read(DataType[] buffer) {
        if (this.currentIndex >= this.array.length) return 0;
        uint bufferLength = cast(uint) buffer.length;
        uint lengthRemaining = cast(uint) this.array.length - this.currentIndex;
        uint lengthToRead = lengthRemaining < bufferLength ? lengthRemaining : bufferLength;
        buffer[0 .. lengthToRead] = this.array[this.currentIndex .. this.currentIndex + lengthToRead];
        this.currentIndex += lengthToRead;
        return lengthToRead;
    }

    void reset() {
        this.currentIndex = 0;
    }
}

unittest {
    import streams.primitives;

    assert(isSomeInputStream!(ArrayInputStream!int));
    assert(isInputStream!(ArrayInputStream!ubyte, ubyte));

    auto s1 = ArrayInputStream!int([1, 2, 3, 4, 5]);
    int[] buffer = new int[2];
    assert(s1.read(buffer) == 2);
    assert(buffer == [1, 2]);
    assert(s1.read(buffer) == 2);
    assert(buffer == [3, 4]);
    assert(s1.read(buffer) == 1);
    assert(buffer == [5, 4]);
}

/** 
 * Creates and returns an array input stream wrapped around the given array
 * of elements.
 * Params:
 *   array = The array to stream.
 * Returns: The array input stream.
 */
ArrayInputStream!T inputStreamFor(T)(T[] array) {
    return ArrayInputStream!T(array);
}

/** 
 * An output stream that writes to an internal array. The resulting array can
 * be obtained with `toArray()`.
 */
struct ArrayOutputStream(DataType) {
    import std.array : Appender, appender;

    private Appender!(DataType[]) app;

    int write(DataType[] buffer) {
        this.app ~= buffer;
        return cast(int) buffer.length;
    }

    /** 
     * Gets the internal array to which elements have been appended.
     * Returns: The internal array.
     */
    DataType[] toArray() {
        return this.app[];
    }

    void reset() {
        this.app = appender!(DataType[])();
    }
}

unittest {
    import streams.primitives;

    assert(isSomeOutputStream!(ArrayOutputStream!bool));

    auto s1 = ArrayOutputStream!float();
    float[] buffer = [0.5, 1, 1.5];
    assert(s1.write(buffer) == 3);
    buffer = [2, 2.5, 3];
    assert(s1.write(buffer) == 3);
    assert(s1.toArray() == [0.5, 1, 1.5, 2, 2.5, 3]);

    auto s2 = ArrayOutputStream!ubyte();
    ubyte[] buffer1 = [1, 2, 3];
    s2.write(buffer1);
    ubyte[] data = s2.toArray();
    assert(data == [1, 2, 3]);
}
