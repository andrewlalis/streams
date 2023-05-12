module streams.types.array;

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

struct ArrayOutputStream(DataType) {
    import std.array : Appender, appender;

    private Appender!DataType app;

    int write(ref DataType[] buffer, uint offset, uint length) {
        app ~= buffer[offset .. offset + length];
    }

    DataType[] toArray() {
        return app[];
    }
}
