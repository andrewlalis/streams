module streams.types.array;

struct ArrayInputStream(DataType) {
    private DataType[] array;
    private uint currentIndex = 0;

    int read(ref DataType[] buffer, uint offset, uint length) {
        uint lengthRemaining = cast(uint) this.array.length - this.currentIndex;
        uint lengthToRead = lengthRemaining < length ? lengthRemaining : length;
        buffer[offset .. offset + lengthToRead] = this.array[this.currentIndex .. this.currentIndex + lengthToRead];
        this.currentIndex += lengthToRead;
        return lengthToRead;
    }
}

unittest {
    import streams.primitives;

    auto s1 = ArrayInputStream!int([1, 2, 3]);

    assert(isSomeInputStream!(ArrayInputStream!int));
    assert(isInputStream!(ArrayInputStream!ubyte, ubyte));
}
