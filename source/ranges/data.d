module ranges.data;

import ranges.base;
import ranges.filter;

import std.traits;

class DataInputRange : FilteredReadableRange {
    this(ReadableRange range) {
        super(range);
    }

    T read(T)() {
        static if (isSomeString!T) {
            return cast(T) readArray!(char[])();
        } else static if (isStaticArray!T) {
            return readStaticArray!T();
        } else static if (isArray!T) {
            return readArray!T();
        } else {
            return readPrimitive!T();
        }
    }

    private T readPrimitive(T)() {
        const byteSize = T.sizeof;
        union U { T value; ubyte[byteSize] bytes; }
        U u;
        int bytesRead = this.range.read(u.bytes, 0, byteSize);
        if (bytesRead != byteSize) {
            import std.format;
            throw new RangeException(format!
                "Failed to read value of type %s (%d bytes) from range. Read %d bytes instead."
                (T.stringof, byteSize, bytesRead)
            );
        }
        return u.value;
    }

    private T readArray(T)() if (isArray!T) {
        uint size;
        try {
            size = readPrimitive!uint();
        } catch (RangeException e) {
            throw new RangeException("Failed to read array size uint.", e);
        }
        alias ElementType = typeof(*T.init.ptr);
        T tempData = new ElementType[size];
        for (uint i = 0; i < size; i++) {
            try {
                tempData[i] = readPrimitive!ElementType();
            } catch (RangeException e) {
                import std.format;
                throw new RangeException(format!
                    "Failed to read array element %d of %d, of type %s."
                    (i + 1, size, ElementType.stringof),
                    e
                );
            }
        }
        return tempData;
    }

    private T readStaticArray(T)() if (isStaticArray!T) {
        alias ElementType = typeof(*T.init.ptr);
        T data;
        for (uint i = 0; i < T.length; i++) {
            try {
                data[i] = readPrimitive!ElementType();
            } catch (RangeException e) {
                throw e;
            }
        }
        return data;
    }
}

class DataOutputRange : FilteredWritableRange {
    this(WritableRange range) {
        super(range);
    }

    void write(T)(T value) {
        static if (isSomeString!T) {
            assert(false, "Cannot write strings.");
        } else {
            writePrimitive!T(value);
        }
    }

    private void writePrimitive(T)(T value) {
        const byteSize = T.sizeof;
        union U { T value; ubyte[byteSize] bytes; }
        U u;
        u.value = value;
        int bytesWritten = this.range.write(u.bytes, 0, byteSize);
        if (bytesWritten != byteSize) {
            import std.format;
            throw new RangeException(format!
                "Failed to write value of type %s (%d bytes, value = %s) to range. Write %d bytes instead.",
                (T.stringof, byteSize, value, bytesWritten)
            );
        }
    }
}

unittest {
    import ranges;
    import std.format;
    DataInputRange dIn = new DataInputRange(new ByteArrayInputRange([0, 0, 0, 0]));
    assert(dIn.read!int == 0);
    dIn = new DataInputRange(new ByteArrayInputRange([1]));
    assert(dIn.read!bool == true);

    ubyte[] buffer = cast(ubyte[]) [12, 0, 0, 0] ~ cast(ubyte[]) "Hello world!";
    dIn = new DataInputRange(new ByteArrayInputRange(buffer));
    assert(dIn.read!string == "Hello world!");
    ubyte[] buffer2 = [4, 0, 0, 0, 1, 2, 3, 4];
    dIn = new DataInputRange(new ByteArrayInputRange(buffer2));
    assert(dIn.read!(ubyte[]) == [1, 2, 3, 4]);

    ubyte[] buffer3 = [1, 2, 3, 4];
    dIn = new DataInputRange(new ByteArrayInputRange(buffer3));
    ubyte[4] output = dIn.read!(ubyte[4])();
    assert(output == [1, 2, 3, 4]);
}
