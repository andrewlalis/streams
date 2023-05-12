/**
 * Defines streams for reading and writing primitive data and arrays of
 * primitive values.
 */
module streams.types.data;

import streams.primitives;
import std.traits;

struct DataInputStream(BaseStream) if (isByteInputStream!BaseStream) {
    private BaseStream* stream;

    int read(ref ubyte[] buffer, uint offset, uint length) {
        return this.stream.read(buffer, offset, length);
    }

    DataType read(DataType)() {
        static if (isSomeString!DataType) {
            return cast(DataType) readArray!(char[])();
        } else static if (isStaticArray!DataType) {
            return readStaticArray!DataType();
        } else static if (isArray!DataType) {
            return readArray!DataType();
        } else {
            return readPrimitive!DataType();
        }
    }

    private T readPrimitive(T)() {
        const byteSize = T.sizeof;
        union U { T value; ubyte[byteSize] bytes; }
        U u;
        ubyte[] buffer = u.bytes[];
        int bytesRead = this.stream.read(buffer, 0, byteSize);
        if (bytesRead != byteSize) {
            import std.format;
            throw new StreamException(format!
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
        } catch (StreamException e) {
            throw new StreamException("Failed to read array size uint.", e);
        }
        alias ElementType = typeof(*T.init.ptr);
        T tempData = new ElementType[size];
        for (uint i = 0; i < size; i++) {
            try {
                tempData[i] = readPrimitive!ElementType();
            } catch (StreamException e) {
                import std.format;
                throw new StreamException(format!
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
            } catch (StreamException e) {
                import std.format;
                throw new StreamException(format!
                    "Failed to read static array element %d of %d, of type %s."
                    (i + 1, T.length, ElementType.stringof),
                    e
                );
            }
        }
        return data;
    }
}

struct DataOutputStream(BaseStream) if (isByteOutputStream!BaseStream) {
    private BaseStream* stream;

    int write(ref ubyte[] buffer, uint offset, uint length) {
        return this.stream.write(buffer, offset, length);
    }

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
        ubyte[] buffer = u.bytes[];
        int bytesWritten = this.stream.write(buffer, 0, byteSize);
        if (bytesWritten != byteSize) {
            import std.format;
            throw new StreamException(format!
                "Failed to write value of type %s (%d bytes, value = %s) to range. Wrote %d bytes instead."
                (T.stringof, byteSize, value, bytesWritten)
            );
        }
    }

    private void writeArray(T)(T value) if (isArray!T) {
        try {
            writePrimitive!uint(cast(uint) value.length);
        } catch (StreamException e) {
            import std.format;
            throw new StreamException("Failed to write array size uint.");
        }
        if (value.length == 0) return;
        alias ElementType = typeof(value[0]);
        for (uint i = 0; i < value.length; i++) {
            try {
                writePrimitive!ElementType(value[i]);
            } catch (StreamException e) {
                import std.format;
                throw new StreamException(format!
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
            } catch (StreamException e) {
                import std.format;
                throw new StreamException(format!
                    "Failed to write static array element %d of %d, of type %s."
                    (i + 1, T.length, ElementType.stringof),
                    e
                );
            }
        }
    }
}

unittest {
    import streams.types.array;
    import streams.factory;

    auto sOut = ArrayOutputStream!ubyte();
    auto dataOut = dataOutputStreamFor(sOut);
    dataOut.write(42);
    dataOut.write(true);
    dataOut.write("Hello");
    ubyte[] data = sOut.toArray();
    auto sIn = inputStreamFor(data);
    auto dataIn = dataInputStreamFor(sIn);
    assert(dataIn.read!int == 42);
    assert(dataIn.read!bool == true);
    assert(dataIn.read!string == "Hello");
}
