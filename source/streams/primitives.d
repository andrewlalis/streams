/**
 * A collection of compile-time functions to help in identifying stream types
 * and related flavors of them.
 *
 * Streams come in two main flavors: ${B input} and ${B output} streams.
 * 
 * ${B Input streams} are defined by the presence of a `read` function with the
 * following signature:
 * ```d
 * int read(ref DataType[] buffer, uint offset, uint length)
 * ```
 *
 * Such a function should read up to `length` elements of type `DataType`
 * from an underlying resource and write them to `buffer`, starting from
 * `offset`.
 *
 * ${B Output streams} are defined by the presence of a `write` function with
 * the following signature:
 * ```d
 * int read(ref DataType[] buffer, uint offset, uint length)
 * ```
 *
 * Such a function should read up to `length` elements of type `DataType` from
 * `buffer` starting from `offset`, and write them to an underlying resource.
 *
 * Usually these functions can be used as [Template Constraints](https://dlang.org/spec/template.html#template_constraints)
 * when defining your own functions and symbols to work with streams.
 * ```d
 * void useBytes(S)(S stream) if (isInputStream!(S, ubyte)) {
 *     ubyte[] buffer = new ubyte[8192];
 *     int bytesRead = stream.read(buffer, 0, 8192);
 *     // Do something with the data.
 * }
 * ```
 */
module streams.primitives;

import std.traits;

/** 
 * Determines if the given template argument is some form of input stream.
 * 
 * An input stream is anything with a `read` method defined like so:
 *
 * ```d
 * int read(ref DataType[] buffer, uint offset, uint length)
 * ```
 * 
 * where the method takes a reference to a buffer, an offset, and a length, and
 * reads up to `length` items from some resource, storing them in `buffer`
 * starting at `offset`. It should return the number of items that were read,
 * or `-1` in case of error.
 * 
 * Some input streams may also throw an exception if an error occurs while
 * reading.
 *
 * Returns: `true` if the given argument is an input stream type, or `false` otherwise.
 */
bool isSomeInputStream(StreamType)() {
    static if (hasMember!(StreamType, "read") && isCallable!(StreamType.read)) {
        alias readFunction = StreamType.read;
        alias params = Parameters!readFunction;
        alias paramStorage = ParameterStorageClassTuple!readFunction;
        static if (params.length == 3 && paramStorage.length == 3) {
            return (
                allSameType!(int, ReturnType!readFunction) &&
                isArray!(params[0]) &&
                paramStorage[0] == ParameterStorageClass.ref_ &&
                is(params[1] == uint) &&
                paramStorage[1] == ParameterStorageClass.none &&
                is(params[2] == uint) &&
                paramStorage[2] == ParameterStorageClass.none
            );
        } else {
            return false;
        }
    } else {
        return false;
    }
}

bool isSomeInputStream2(S)() {
    return hasMember!(S, "read") &&
        isCallable!(S.read) &&
        Parameters!(S.read).length == 1 &&
        is(ReturnType!(S.read) == int) &&
        isDynamicArray!(Parameters!(S.read)[0]);
}

unittest {
    struct S1 {
        int read(ubyte[] buffer) {
            int sum = 0;
            foreach (n; buffer) sum += n;
            return sum;
        }

        int write(ubyte[] buffer) {
            return 0;
        }
    }
    assert(isSomeInputStream2!S1);
    S1 s1;
    ubyte[] buffer = [1, 2, 3];
    import core.stdc.stdlib;
    ubyte* ptr = cast(ubyte*) malloc(3 * ubyte.sizeof);
    ptr[0] = 1;
    ptr[1] = 2;
    ptr[2] = 3;
    assert(s1.read(buffer) == 6);
    assert(s1.read(ptr[0..3]) == 6);
}

/** 
 * Determines if the given template argument is some form of output stream.
 * ```d
 * int write(ref DataType[] buffer, uint offset, uint length)
 * ```
 * Returns: True if the given argument is an output stream type, or false otherwise.
 */
bool isSomeOutputStream(StreamType)() {
    static if (hasMember!(StreamType, "write") && isCallable!(StreamType.write)) {
        alias writeFunction = StreamType.write;
        alias params = Parameters!writeFunction;
        alias paramStorage = ParameterStorageClassTuple!writeFunction;
        static if (params.length == 3 && paramStorage.length == 3) {
            return (
                allSameType!(int, ReturnType!writeFunction) &&
                isArray!(params[0]) &&
                paramStorage[0] == ParameterStorageClass.ref_ &&
                is(params[1] == uint) &&
                paramStorage[1] == ParameterStorageClass.none &&
                is(params[2] == uint) &&
                paramStorage[2] == ParameterStorageClass.none
            );
        } else {
            return false;
        }
    } else {
        return false;
    }
}

/** 
 * Determines if the given stream type is an input stream for reading data of
 * the given type.
 * Returns: True if the given stream type is an input stream, or false otherwise.
 */
bool isInputStream(StreamType, DataType)() {
    static if (isSomeInputStream!StreamType) {
        return is(Parameters!(StreamType.read)[0] == DataType[]);
    } else {
        return false;
    }
}

unittest {
    // Test a valid input stream.
    struct S1 {
        int read(ref ubyte[] buffer, uint offset, uint length) {
            return 0; // Don't do anything with the data.
        }
    }
    assert(isInputStream!(S1, ubyte));

    // Test a few invalid input streams.
    struct S2 {}
    assert(!isInputStream!(S2, ubyte));
    struct S3 {
        void read(ref ubyte[] buffer, uint offset, uint length) {
            // Invalid return type!
        }
    }
    assert(!isInputStream!(S3, ubyte));
    struct S4 {
        int read(ubyte[] buffer) {
            return 0; // Missing required arguments.
        }
    }
    assert(!isInputStream!(S4, ubyte));
    class C1 {
        int read(ref char[] buffer, uint offset, uint length) {
            return 0;
        }
    }
    assert(isInputStream!(C1, char));
}

/** 
 * Determines if the given stream type is an output stream for writing data of
 * the given type.
 * Returns: True if the given stream type is an output stream, or false otherwise.
 */
bool isOutputStream(StreamType, DataType)() {
    static if (isSomeOutputStream!StreamType) {
        return is(Parameters!(StreamType.write)[0] == DataType[]);
    } else {
        return false;
    }
}

unittest {
    // Test a valid output stream.
    struct S1 {
        int write(ref ubyte[] buffer, uint offset, uint length) {
            return 0; // Don't do anything with the data.
        }
    }
    assert(isOutputStream!(S1, ubyte));

    // Test a few invalid output streams.
    struct S2 {}
    assert(!isOutputStream!(S2, ubyte));
    struct S3 {
        void write(ref ubyte[] buffer, uint offset, uint length) {
            // Invalid return type!
        }
    }
    assert(!isOutputStream!(S3, ubyte));
    struct S4 {
        int write(ubyte[] buffer) {
            return 0; // Missing required arguments.
        }
    }
    assert(!isOutputStream!(S4, ubyte));
}

/** 
 * Determines if the given template argument is a stream of any kind; that is,
 * it is at least implementing the functions required to be an input or output
 * stream.
 * Returns: True if the given argument is some stream.
 */
bool isSomeStream(StreamType)() {
    return isSomeInputStream!StreamType || isSomeOutputStream!StreamType;
}

unittest {
    struct S1 {
        int read(ref ubyte[] buffer, uint offset, uint count) {
            return 0;
        }
    }
    assert(isSomeStream!S1);
    struct S2 {
        int write(ref ubyte[] buffer, uint offset, uint count) {
            return 0;
        }
    }
    assert(isSomeStream!S2);
    struct S3 {}
    assert(!isSomeStream!S3);
}

/** 
 * Determines if the given stream type is an input or output stream for data of
 * the given type.
 * Returns: True if the stream type is an input or output stream for the given data type.
 */
bool isSomeStream(StreamType, DataType)() {
    return isInputStream!(StreamType, DataType) || isOutputStream(StreamType, DataType);
}

bool isByteInputStream(StreamType)() {
    return isInputStream!(StreamType, ubyte);
}

bool isByteOutputStream(StreamType)() {
    return isOutputStream!(StreamType, ubyte);
}

/** 
 * Determines if the given template argument is a closable stream type, which
 * provides the following function:
 *
 * ```d
 * void close()
 * ```
 *
 * Closable streams provide this function as a means to close and/or deallocate
 * the underlying resource that they're reading from or writing to. Calling
 * this function may, depending on the implementation, throw an exception.
 *
 * Returns: True if the given argument is a closable stream, or false otherwise.
 */
bool isClosableStream(StreamType)() {
    static if (
        isSomeStream!StreamType &&
        hasMember!(StreamType, "close") &&
        isCallable!(StreamType.close)
    ) {
        alias closeFunction = StreamType.close;
        alias params = Parameters!closeFunction;
        return (
            allSameType!(void, ReturnType!closeFunction) &&
            params.length == 0
        );
    } else {
        return false;
    }
}

unittest {
    struct S1 {
        int read(ref ubyte[] buffer, uint offset, uint count) {
            return 0;
        }
        void close() {}
    }
    assert(isClosableStream!S1);
    struct S2 {
        int read(ref ubyte[] buffer, uint offset, uint count) {
            return 0;
        }
    }
    assert(!isClosableStream!S2);
    struct S3 {}
    assert(!isClosableStream!S3);
}

/** 
 * Determines if the given template argument is a flushable stream type, which
 * provides the following function:
 *
 * ```d
 * void flush()
 * ```
 *
 * Flushable streams are a flavor of output stream that may buffer data that
 * has been written via its `write` function, and calling `flush()` on such a
 * stream should force a true write operation to the stream's underlying
 * resource.
 *
 * Returns: True if the given argument is a flushable stream, or false otherwise.
 */
bool isFlushableStream(StreamType)() {
    import std.traits;
    static if (
        isSomeOutputStream!StreamType &&
        hasMember!(StreamType, "flush") &&
        isCallable!(StreamType.flush)
    ) {
        alias flushFunction = StreamType.flush;
        alias params = Parameters!flushFunction;
        return (
            allSameType!(void, ReturnType!flushFunction) &&
            params.length == 0
        );
    } else {
        return false;
    }
}

unittest {
    struct S1 {
        int write(ref ubyte[] buffer, uint offset, uint count) {
            return 0;
        }
        void flush() {}
    }
    assert(isFlushableStream!S1);
    struct S2 {
        int write(ref ubyte[] buffer, uint offset, uint count) {
            return 0;
        }
    }
    assert(!isFlushableStream!S2);
    struct S3 {}
    assert(!isFlushableStream!S3);
}

/** 
 * An exception that may be thrown if an illegal operation or error occurs
 * while working with streams.
 */
class StreamException : Exception {
    import std.exception;

    mixin basicExceptionCtors;
}
