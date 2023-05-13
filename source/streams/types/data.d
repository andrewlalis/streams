/**
 * Defines streams for reading and writing primitive data and arrays of
 * primitive values. So-called "data" input and output streams are defined as
 * decorators around an existing "base" stream, so when you read or write on
 * a data stream, it's just performing an analogous operation on its base
 * stream.
 */
module streams.types.data;

import streams.primitives;
import std.traits;
import std.typecons;

/** 
 * Information about an error that occurred while reading or writing in a
 * data stream.
 */
struct DataStreamError {
    /** 
     * A description of the error that occurred.
     */
    const(char[]) message;
    /** 
     * The return value from the stream operation that caused the error.
     */
    const int lastStreamResult;
}

/** 
 * The result of a data input stream read operation, which is either a value
 * or an error.
 */
struct DataReadResult(T) {
    /** 
     * The value that was read. Is null only if there's an error.
     */
    const Nullable!T value;

    /** 
     * The error that occurred. Is only present if an error actually occurred.
     */
    const Nullable!DataStreamError error;

    /** 
     * Constructs a result containing a value that was successfully read.
     * Params:
     *   value = The value that was read.
     */
    this(T value) {
        this.value = Nullable!T(value);
        this.error = Nullable!DataStreamError.init;
    }

    /** 
     * Constructs a result containing an error that occurred while reading.
     * Params:
     *   error = The error that occurred.
     */
    this(DataStreamError error) {
        this.error = Nullable!DataStreamError(error);
        this.value = Nullable!T.init;
    }

    // Ensure an XOR relationship between value and error.
    // Either we have a value, or we have an error.
    invariant {
        assert((value.isNull || error.isNull) && !(value.isNull && error.isNull));
    }
}

/** 
 * An output stream that is wrapped around a byte output stream, so that values
 * may be written to the stream as bytes.
 */
struct DataInputStream(S) if (isByteInputStream!S) {
    private S* stream;

    /** 
     * Constructs a data input stream that reads from a given underlying byte
     * input stream.
     * Params:
     *   stream = The stream to read from.
     */
    this(ref S stream) {
        this.stream = &stream;
    }

    /** 
     * Delegates reading to the underlying stream.
     * Params:
     *   buffer = The buffer to read to.
     * Returns: The number of bytes read.
     */
    int read(ubyte[] buffer) {
        return this.stream.read(buffer);
    }

    /** 
     * Reads a value from the stream.
     * Returns: A result containing either that value that was read, or an error.
     */
    DataReadResult!T read(T)() {
        static if (isStaticArray!T) {
            return readStaticArray!T();
        } else static if (isScalarType!T) {
            return readScalar!T();
        } else {
            static assert(
                false,
                "Cannot read values of type " ~ T.stringof ~ ". " ~
                "Only scalar types and static arrays are supported."
            );
        }
    }

    version (D_BetterC) {} else {
        /** 
         * Reads a value from the stream and throws a StreamException if reading
         * failed for any reason.
         * Returns: The value that was read.
         */
        T readOrThrow(T)() {
            DataReadResult!T result = this.read!T();
            if (!result.error.isNull) {
                throw new StreamException(cast(string) result.error.get().message);
            }
            return result.value.get();
        }
    }

    private DataReadResult!T readScalar(T)() {
        union U { T value; ubyte[T.sizeof] bytes; }
        U u;
        int bytesRead = this.stream.read(u.bytes[]);
        if (bytesRead != T.sizeof) {
            return DataReadResult!T(DataStreamError(
                "Failed to read scalar value of type \"" ~ T.stringof ~ "\"" ~
                " from stream of type \"" ~ S.stringof ~ "\".",
                bytesRead
            ));
        }
        return DataReadResult!T(u.value);
    }

    private DataReadResult!T readStaticArray(T)() {
        static if (T.length == 0) return DataReadResult!T(T[0]);
        alias ElementType = typeof(*T.init.ptr);
        T data;
        for (uint i = 0; i < T.length; i++) {
            DataReadResult!ElementType elementResult = read!ElementType();
            if (!elementResult.error.isNull) {
                return DataReadResult!T(elementResult.error.get());
            }
            data[i] = elementResult.value.get();
        }
        return DataReadResult!T(data);
    }
}

/** 
 * Creates and returns a data input stream that's wrapped around the given
 * byte input stream.
 * Params:
 *   stream = The stream to wrap in a data input stream.
 * Returns: The data input stream.
 */
DataInputStream!S dataInputStreamFor(S)(
    ref S stream
) if (isByteInputStream!S) {
    return DataInputStream!S(stream);
}

/** 
 * An input stream that is wrapped around a byte input stream, so that values
 * may be read from the stream as bytes.
 */
struct DataOutputStream(S) if (isByteOutputStream!S) {
    private S* stream;

    /** 
     * Constructs the data output stream so it will write to the given stream.
     * Params:
     *   stream = The stream to write to.
     */
    this(ref S stream) {
        this.stream = &stream;
    }

    /** 
     * Delegates writing to the underlying stream.
     * Params:
     *   buffer = The buffer whose contents to write.
     * Returns: The number of bytes written.
     */
    int write(ubyte[] buffer) {
        return this.stream.write(buffer);
    }

    /** 
     * Writes a value of type `T` to the stream. If writing fails for
     * whatever reason, a StreamException is thrown.
     * Params:
     *   value = The value to write.
     * Returns: A nullable error, which is set if an error occurs.
     */
    Nullable!DataStreamError write(T)(T value) {
        static if (isStaticArray!T) {
            return writeStaticArray!T(value);
        } else static if (isScalarType!T) {
            return writeScalar!T(value);
        } else {
            static assert(
                false,
                "Cannot read values of type " ~ T.stringof ~ ". " ~
                "Only scalar types and static arrays are supported."
            );
        }
    }

    private Nullable!DataStreamError writeScalar(T)(T value) {
        union U { T value; ubyte[T.sizeof] bytes; }
        U u;
        u.value = value;
        int bytesWritten = this.stream.write(u.bytes[]);
        if (bytesWritten != T.sizeof) {
            return Nullable!DataStreamError(DataStreamError(
                "Failed to write scalar value of type \"" ~ T.stringof ~ "\"" ~
                " to stream of type \"" ~ S.stringof ~ "\".",
                bytesWritten
            ));
        }
        return Nullable!DataStreamError.init;
    }

    private Nullable!DataStreamError writeStaticArray(T)(T value) if (isStaticArray!T) {
        static if (T.length == 0) return;
        alias ElementType = typeof(*T.init.ptr);
        for (uint i = 0; i < T.length; i++) {
            Nullable!DataStreamError error = write!ElementType(value[i]);
            if (!error.isNull) {
                return error;
            }
        }
        return Nullable!DataStreamError.init;
    }
}

/** 
 * Creates and returns a data output stream that's wrapped around the given
 * byte output stream.
 * Params:
 *   stream = The stream to wrap in a data output stream.
 * Returns: The data output stream.
 */
DataOutputStream!S dataOutputStreamFor(S)(
    ref S stream
) if (isByteOutputStream!S) {
    return DataOutputStream!S(stream);
}

unittest {
    import streams.types.array;

    auto sOut = ArrayOutputStream!ubyte();
    auto dataOut = dataOutputStreamFor(sOut);
    dataOut.write(42);
    dataOut.write(true);
    dataOut.write(cast(char[5]) "Hello");
    ubyte[] data = sOut.toArray();
    auto sIn = inputStreamFor(data);
    auto dataIn = dataInputStreamFor(sIn);
    assert(dataIn.readOrThrow!int == 42);
    assert(dataIn.readOrThrow!bool == true);
    assert(dataIn.readOrThrow!(char[5]) == "Hello");
    DataReadResult!ubyte result = dataIn.read!ubyte();
    assert(result.value.isNull);
    assert(result.error.get().lastStreamResult == 0);

    // Test that reading normally still works.
    auto sIn1 = inputStreamFor!ubyte([1, 2, 3, 4]);
    auto dataIn1 = dataInputStreamFor(sIn1);
    ubyte[] buffer1 = new ubyte[3];
    assert(dataIn1.read(buffer1) == 3);
    assert(buffer1 == [1, 2, 3]);

    // Test that writing normally still works.
    auto sOut1 = ArrayOutputStream!ubyte();
    auto dataOut1 = dataOutputStreamFor(sOut1);
    dataOut1.write([1, 2, 3]);
    assert(sOut1.toArray() == [1, 2, 3]);

    // Test that calling readOrThrow throws an exception with invalid data.
    auto sIn2 = inputStreamFor!ubyte([1, 2, 3]);
    auto dataIn2 = dataInputStreamFor(sIn2);
    try {
        dataIn2.readOrThrow!int();
        assert(false, "Failed to throw exception.");
    } catch (StreamException e) {
        // This is expected.
    }

    // Test that reading a static array with invalid data returns an error.
    auto sIn3 = inputStreamFor!ubyte([1, 2, 3]);
    auto dataIn3 = dataInputStreamFor(sIn3);
    DataReadResult!(ubyte[4]) result3 = dataIn3.read!(ubyte[4])();
    assert(result3.value.isNull);
    assert(result3.error.get().lastStreamResult == 0);
}
