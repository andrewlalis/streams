/**
 * This module defines the `DataInputRange` and `DataOutputRange` as utility
 * ranges for reading and writing primitive values and arrays.
 */
module ranges.data;

import ranges.base;
import ranges.filter;

import std.traits;

class DataInputRange : FilteredReadableRange {
    this(ReadableRange range) {
        super(range);
    }

    alias read = FilteredReadableRange.read;

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
                import std.format;
                throw new RangeException(format!
                    "Failed to read static array element %d of %d, of type %s."
                    (i + 1, T.length, ElementType.stringof),
                    e
                );
            }
        }
        return data;
    }
}

class DataOutputRange : FilteredWritableRange {
    this(WritableRange range) {
        super(range);
    }

    alias write = FilteredWritableRange.write;

    void write(T)(T value) {
        static if (isSomeString!T) {
            writeArray!(char[])(cast(char[]) value);
        } else static if (isStaticArray!T) {
            writeStaticArray!T(value);
        } else static if (isArray!T) {
            writeArray!T(value);
        } else {
            writePrimitive!T(value);
        }
    }

    private void writePrimitive(T)(T value) {
        const uint byteSize = T.sizeof;
        union U { T value; ubyte[byteSize] bytes; }
        U u;
        u.value = value;
        int bytesWritten = this.range.write(u.bytes, 0, byteSize);
        if (bytesWritten != byteSize) {
            import std.format;
            throw new RangeException(format!
                "Failed to write value of type %s (%d bytes, value = %s) to range. Wrote %d bytes instead."
                (T.stringof, byteSize, value, bytesWritten)
            );
        }
    }

    private void writeArray(T)(T value) if (isArray!T) {
        try {
            writePrimitive!uint(cast(uint) value.length);
        } catch (RangeException e) {
            import std.format;
            throw new RangeException("Failed to write array size uint.");
        }
        if (value.length == 0) return;
        alias ElementType = typeof(value[0]);
        for (uint i = 0; i < value.length; i++) {
            try {
                writePrimitive!ElementType(value[i]);
            } catch (RangeException e) {
                import std.format;
                throw new RangeException(format!
                    "Failed to write array element %d of %d, of type %s."
                    (i + 1, value.length, ElementType.stringof),
                    e
                );
            }
        }
    }

    private void writeStaticArray(T)(T value) if (isStaticArray!T) {
        static if (T.length == 0) return;
        alias ElementType = typeof(*T.init.ptr);
        for (uint i = 0; i < T.length; i++) {
            try {
                writePrimitive!ElementType(value[i]);
            } catch (RangeException e) {
                import std.format;
                throw new RangeException(format!
                    "Failed to write static array element %d of %d, of type %s."
                    (i + 1, T.length, ElementType.stringof),
                    e
                );
            }
        }
    }
}

// Tests for DataInputRange
unittest {
    import ranges;
    import std.format;

    DataInputRange getInputRange(ubyte[] buffer) {
        return new DataInputRange(new ByteArrayInputRange(buffer));
    }

    DataInputRange din;

    // Test reading some integers.
    union IntUnion { int value; ubyte[4] bytes; }
    int[] testValues = [int.min, -1, 0, 1, 42, int.max];
    foreach (value; testValues) {
        IntUnion u;
        u.value = value;
        din = getInputRange(u.bytes[]);
        assert(din.read!int() == value);
    }
    // Try all at once.
    ubyte[] buffer;
    foreach (value; testValues) {
        IntUnion u;
        u.value = value;
        buffer ~= u.bytes[];
    }
    din = getInputRange(buffer);
    foreach (value; testValues) {
        assert(din.read!int() == value);
    }

    // Test some booleans.
    din = getInputRange([0, 1, 43, ubyte.max]);
    assert(din.read!bool() == false);
    assert(din.read!bool() == true);
    assert(din.read!bool() == true);
    assert(din.read!bool() == true);

    // Test reading a static array (aka no length prefix)
    float[3] vec = [0.5, 1.0, 0.75];
    buffer = [];
    union FloatUnion { float value; ubyte[4] bytes; }
    foreach (value; vec) {
        FloatUnion u;
        u.value = value;
        buffer ~= u.bytes[];
    }
    din = getInputRange(buffer);
    float[3] outputVec = din.read!(float[3])();
    assert(outputVec == vec);

    // Test reading an array (with length prefix)
    buffer = [];
    IntUnion sizeUnion;
    sizeUnion.value = cast(int) testValues.length;
    buffer ~= sizeUnion.bytes[];
    foreach (value; testValues) {
        IntUnion u;
        u.value = value;
        buffer ~= u.bytes[];
    }
    din = getInputRange(buffer);
    int[] readTestValues = din.read!(int[])();
    assert(readTestValues == testValues);

    // Test reading a string.
    buffer = cast(ubyte[]) [12, 0, 0, 0] ~ cast(ubyte[]) "Hello world!";
    din = getInputRange(buffer);
    assert(din.read!string == "Hello world!");


    // Tests for DataOutputRange
    auto r = new ByteArrayOutputRange();
    DataOutputRange dout = new DataOutputRange(r);
    dout.write!long(123_456_789_101_123);
    buffer = r.toArray();
    din = getInputRange(buffer);
    assert(din.read!long() == 123_456_789_101_123);

    r = new ByteArrayOutputRange();
    dout = new DataOutputRange(r);
    dout.write!(int[])(testValues);
    buffer = r.toArray();
    din = getInputRange(buffer);
    assert(din.read!(int[]) == testValues);
}
