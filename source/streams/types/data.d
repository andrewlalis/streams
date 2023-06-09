/**
 * Defines streams for reading and writing primitive data and arrays of
 * primitive values. So-called "data" input and output streams are defined as
 * decorators around an existing "base" stream, so when you read or write on
 * a data stream, it's just performing an analogous operation on its base
 * stream.
 */
module streams.types.data;

import streams.primitives;
import streams.utils : Optional, Either;
import std.traits : isScalarType, isStaticArray;

/**
 * The result of a data input stream read operation, which is either a value
 * or an error.
 */
alias DataReadResult(T) = Either!(T, "value", StreamError, "error");

/** 
 * An enum defining the endianness of a stream, which is how it assumes data on
 * the underlying resource to be written and read, irrespective of the system
 * endianness.
 */
enum Endianness { BigEndian, LittleEndian }

version (BigEndian) {
    immutable Endianness SYSTEM_ENDIANNESS = Endianness.BigEndian;
} else {
    immutable Endianness SYSTEM_ENDIANNESS = Endianness.LittleEndian;
}

/** 
 * A helper function that flips a static array's elements if needed so that its
 * byte order matches a target byte order.
 * Params:
 *   bytes = The bytes to possibly flip.
 *   sourceOrder = The byte order of the source that produced the bytes.
 *   targetOrder = The byte order of the consumer of the bytes.
 */
private void ensureByteOrder(T)(
    ref ubyte[T.sizeof] bytes,
    Endianness sourceOrder,
    Endianness targetOrder
) if (isScalarType!T) {
    if (sourceOrder != targetOrder) {
        ubyte tmp;
        static foreach (i; 0 .. T.sizeof / 2) {
            tmp = bytes[i];
            bytes[i] = bytes[T.sizeof - 1 - i];
            bytes[T.sizeof - 1 - i] = tmp;
        }
    }
}

/** 
 * An input stream that is wrapped around a byte input stream, so that values
 * may be read from the stream as bytes.
 */
struct DataInputStream(S) if (isByteInputStream!S) {
    private S stream;
    private immutable Endianness endianness = SYSTEM_ENDIANNESS;

    /** 
     * Constructs a data input stream that reads from a given underlying byte
     * input stream.
     * Params:
     *   stream = The stream to read from.
     *   endianness = The byte order of the resource that this stream is
     *                reading from. Defaults to the system byte order.
     */
    this(S stream, Endianness endianness = SYSTEM_ENDIANNESS) {
        this.stream = stream;
        this.endianness = endianness;
    }

    /** 
     * Delegates reading to the underlying stream.
     * Params:
     *   buffer = The buffer to read to.
     * Returns: The number of bytes read.
     */
    StreamResult readFromStream(ubyte[] buffer) {
        return this.stream.readFromStream(buffer);
    }

    /** 
     * Reads a value from the stream and returns either the value that was
     * read successfully, or an error message. If you want to ignore errors,
     * you can use `readFromStreamOrDefault` instead.
     * Returns: A result containing either that value that was read, or an error.
     */
    DataReadResult!T readFromStream(T)() {
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

    /** 
     * Reads a value from the stream, or return a default value if reading
     * fails for any reason.
     * Params:
     *   defaultValue = The default value to return if reading fails.
     * Returns: The value that was read, or a default value.
     */
    T readFromStreamOrDefault(T)(T defaultValue = T.init) {
        DataReadResult!T result = this.readFromStream!T();
        if (result.hasValue) return result.value;
        return defaultValue;
    }

    private DataReadResult!T readScalar(T)() {
        union U { T value; ubyte[T.sizeof] bytes; }
        U u;
        StreamResult readResult = this.stream.readFromStream(u.bytes[]);
        if (readResult.hasError) return DataReadResult!T(readResult.error);
        if (readResult.count != T.sizeof) {
            return DataReadResult!T(StreamError(
                "Failed to read scalar value of type \"" ~ T.stringof ~ "\"" ~
                " from stream of type \"" ~ S.stringof ~ "\".",
                readResult.count
            ));
        }
        ensureByteOrder!T(u.bytes, SYSTEM_ENDIANNESS, this.endianness);
        return DataReadResult!T(u.value);
    }

    private DataReadResult!T readStaticArray(T)() {
        static if (T.length == 0) return DataReadResult!T(T[0]);
        alias ElementType = typeof(*T.init.ptr);
        T data;
        for (uint i = 0; i < T.length; i++) {
            DataReadResult!ElementType elementResult = readFromStream!ElementType();
            if (elementResult.hasError) {
                return DataReadResult!T(elementResult.error);
            }
            data[i] = elementResult.value;
        }
        return DataReadResult!T(data);
    }
}

/** 
 * Creates and returns a data input stream that's wrapped around the given
 * byte input stream.
 * Params:
 *   stream = The stream to wrap in a data input stream.
 *   endianness = The byte order of the resource that this stream is
 *                reading from. Defaults to the system byte order.
 * Returns: The data input stream.
 */
DataInputStream!S dataInputStreamFor(S)(
    S stream,
    Endianness endianness = SYSTEM_ENDIANNESS
) if (isByteInputStream!S) {
    return DataInputStream!S(stream, endianness);
}

/** 
 * An output stream that is wrapped around a byte output stream, so that values
 * may be written to the stream as bytes.
 */
struct DataOutputStream(S) if (isByteOutputStream!S) {
    private S stream;
    private immutable Endianness endianness;

    /** 
     * Constructs the data output stream so it will write to the given stream.
     * Params:
     *   stream = The stream to write to.
     *   endianness = The byte order of the resource we're writing to. Defaults
     *                to the system byte order.
     */
    this(S stream, Endianness endianness = SYSTEM_ENDIANNESS) {
        this.stream = stream;
        this.endianness = endianness;
    }

    /** 
     * Delegates writing to the underlying stream.
     * Params:
     *   buffer = The buffer whose contents to write.
     * Returns: The number of bytes written.
     */
    StreamResult writeToStream(ubyte[] buffer) {
        return stream.writeToStream(buffer);
    }

    /** 
     * Writes a value of type `T` to the stream. If writing fails for
     * whatever reason, a StreamException is thrown.
     * Params:
     *   value = The value to write.
     * Returns: A nullable error, which is set if an error occurs.
     */
    OptionalStreamError writeToStream(T)(T value) {
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

    private OptionalStreamError writeScalar(T)(T value) {
        union U { T value; ubyte[T.sizeof] bytes; }
        U u;
        u.value = value;
        ensureByteOrder!T(u.bytes, this.endianness, SYSTEM_ENDIANNESS);
        StreamResult writeResult = this.stream.writeToStream(u.bytes[]);
        if (writeResult.hasError) return OptionalStreamError(writeResult.error);
        if (writeResult.count != T.sizeof) {
            return OptionalStreamError(StreamError(
                "Failed to write scalar value of type \"" ~ T.stringof ~ "\"" ~
                " to stream of type \"" ~ S.stringof ~ "\".",
                writeResult.count
            ));
        }
        return OptionalStreamError.init;
    }

    private OptionalStreamError writeStaticArray(T)(T value) if (isStaticArray!T) {
        static if (T.length == 0) return;
        alias ElementType = typeof(*T.init.ptr);
        for (uint i = 0; i < T.length; i++) {
            OptionalStreamError error = writeToStream!ElementType(value[i]);
            if (error.present) {
                return error;
            }
        }
        return OptionalStreamError.init;
    }
}

/** 
 * Creates and returns a data output stream that's wrapped around the given
 * byte output stream.
 * Params:
 *   stream = The stream to wrap in a data output stream.
 *   endianness = The byte order of the resource we're writing to. Defaults
 *                to the system byte order.
 * Returns: The data output stream.
 */
DataOutputStream!S dataOutputStreamFor(S)(
    S stream,
    Endianness endianness = SYSTEM_ENDIANNESS
) if (isByteOutputStream!S) {
    return DataOutputStream!S(stream, endianness);
}

unittest {
    import streams.primitives : ErrorOutputStream;
    import streams.types.array : arrayOutputStreamFor, arrayInputStreamFor, byteArrayOutputStream;

    auto sOut = arrayOutputStreamFor!ubyte;
    auto dataOut = dataOutputStreamFor(&sOut);
    dataOut.writeToStream!int(42);
    dataOut.writeToStream(true);
    char[5] word = "Hello";
    dataOut.writeToStream(word);
    ubyte[] data = sOut.toArrayRaw();
    auto sIn = arrayInputStreamFor(data);
    auto dataIn = dataInputStreamFor(&sIn);
    assert(dataIn.readFromStreamOrDefault!int() == 42);
    assert(dataIn.readFromStreamOrDefault!bool() == true);
    assert(dataIn.readFromStreamOrDefault!(char[5]) == word);
    DataReadResult!ubyte result = dataIn.readFromStream!ubyte();
    assert(result.hasError);
    assert(result.error.code == 0);

    // Test that reading normally still works.
    ubyte[4] sIn1Data = [1, 2, 3, 4];
    auto sIn1 = arrayInputStreamFor!ubyte(sIn1Data);
    auto dataIn1 = dataInputStreamFor(&sIn1);
    ubyte[3] buffer1;
    assert(dataIn1.readFromStream(buffer1) == StreamResult(3));
    ubyte[3] buffer1Expected = [1, 2, 3];
    assert(buffer1 == buffer1Expected);

    // Test that writing normally still works.
    auto sOut1 = arrayOutputStreamFor!ubyte;
    auto dataOut1 = dataOutputStreamFor(&sOut1);
    ubyte[3] buffer2 = [1, 2, 3];
    dataOut1.writeToStream(buffer2);
    assert(sOut1.toArrayRaw() == buffer2);

    // Test that reading a static array with invalid data returns an error.
    ubyte[3] buffer3 = [1, 2, 3];
    auto sIn3 = arrayInputStreamFor!ubyte(buffer3);
    auto dataIn3 = dataInputStreamFor(&sIn3);
    DataReadResult!(ubyte[4]) result3 = dataIn3.readFromStream!(ubyte[4])();
    assert(result3.hasError);
    assert(result3.error.code == 0);

    // Test that writing a value to an output stream that doesn't write all bytes, causes an error.
    auto sOut3 = NoOpOutputStream!ubyte();
    auto dataOut3 = dataOutputStreamFor(&sOut3);
    assert(dataOut3.writeToStream(42u).present);

    // Test that writing a value to an output stream that errors, also causes an error.
    auto sOut4 = ErrorOutputStream!ubyte();
    auto dataOut4 = dataOutputStreamFor(&sOut4);
    OptionalStreamError error4 = dataOut4.writeToStream(1);
    assert(error4.present);

    // Test that writing a static array fails if writing one element fails.
    auto sOut5 = ErrorOutputStream!ubyte();
    auto dataOut5 = dataOutputStreamFor(&sOut5);
    OptionalStreamError error5 = dataOut5.writeToStream!(int[3])([3, 2, 1]);
    assert(error5.present);

    // Test that writing to an array with opposite byte order works as expected.
    auto sOut6 = byteArrayOutputStream();
    auto dataOut6 = dataOutputStreamFor(&sOut6, Endianness.BigEndian);
    dataOut6.writeToStream!short(1);
    assert(sOut6.toArrayRaw() == [0, 1]);
    sOut6.reset();
    auto dataOut7 = dataOutputStreamFor(&sOut6, Endianness.LittleEndian);
    dataOut7.writeToStream!short(1);
    assert(sOut6.toArrayRaw() == [1, 0]);

    // Test that readOrDefault works.
    ubyte[4] data7 = [1, 2, 3, 4];
    auto sIn7 = arrayInputStreamFor(data7);
    auto dataIn7 = dataInputStreamFor(&sIn7);
    for (uint i = 0; i < 4; i++) {
        assert(dataIn7.readFromStreamOrDefault!ubyte() == data7[i]);
    }
    assert(dataIn7.readFromStreamOrDefault!ubyte(42) == 42);
}
