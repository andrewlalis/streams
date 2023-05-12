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

    int read(ref DataType[] buffer, uint offset, uint length) {
        if (this.currentIndex >= this.array.length) return 0;
        uint lengthRemaining = cast(uint) this.array.length - this.currentIndex;
        uint lengthToRead = lengthRemaining < length ? lengthRemaining : length;
        buffer[offset .. offset + lengthToRead] = this.array[this.currentIndex .. this.currentIndex + lengthToRead];
        this.currentIndex += lengthToRead;
        return lengthToRead;
    }
}

unittest {
    import streams.primitives;

    assert(isSomeInputStream!(ArrayInputStream!int));
    assert(isInputStream!(ArrayInputStream!ubyte, ubyte));

    auto s1 = ArrayInputStream!int([1, 2, 3, 4, 5]);
    int[] buffer = new int[2];
    assert(s1.read(buffer, 0, 2) == 2);
    assert(buffer == [1, 2]);
    assert(s1.read(buffer, 0, 2) == 2);
    assert(buffer == [3, 4]);
    assert(s1.read(buffer, 0, 2) == 1);
    assert(buffer == [5, 4]);
}

/** 
 * An output stream that writes to an internal array. The resulting array can
 * be obtained with `toArray()`.
 */
struct ArrayOutputStream(DataType) {
    import std.array : Appender, appender;

    private Appender!(DataType[]) app;

    int write(ref DataType[] buffer, uint offset, uint length) {
        this.app ~= buffer[offset .. offset + length];
        return length;
    }

    DataType[] toArray() {
        return this.app[];
    }
}

unittest {
    import streams.primitives;

    assert(isSomeOutputStream!(ArrayOutputStream!bool));

    auto s1 = ArrayOutputStream!float();
    float[] buffer = [0.5, 1, 1.5];
    assert(s1.write(buffer, 0, 3) == 3);
    buffer = [2, 2.5, 3];
    assert(s1.write(buffer, 0, 3) == 3);
    assert(s1.toArray() == [0.5, 1, 1.5, 2, 2.5, 3]);

    auto s2 = ArrayOutputStream!ubyte();
    ubyte[] buffer1 = [1, 2, 3];
    s2.write(buffer1, 0, 3);
    ubyte[] data = s2.toArray();
    assert(data == [1, 2, 3]);
}
