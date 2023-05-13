/**
 * A collection of compile-time functions to help in identifying stream types
 * and related flavors of them.
 *
 * Streams come in two main flavors: ${B input} and ${B output} streams.
 * 
 * ${B Input streams} are defined by the presence of a `read` function with the
 * following signature:
 * ```d
 * int read(DataType[] buffer)
 * ```
 *
 * ${B Output streams} are defined by the presence of a `write` function with
 * the following signature:
 * ```d
 * int read(DataType[] buffer)
 * ```
 *
 * Usually these functions can be used as [Template Constraints](https://dlang.org/spec/template.html#template_constraints)
 * when defining your own functions and symbols to work with streams.
 * ```d
 * void useBytes(S)(S stream) if (isInputStream!(S, ubyte)) {
 *     ubyte[] buffer = new ubyte[8192];
 *     int bytesRead = stream.read(buffer);
 *     // Do something with the data.
 * }
 * ```
 */
module streams.primitives;

import std.traits;
import std.range;

/** 
 * Determines if the given template argument is some form of input stream,
 * where an input stream is anything with a `read` method that takes a single
 * array parameter, and returns an integer number of elements that were read,
 * or -1 in case of error. This method does not care about the type of elements
 * that can be read by the stream.
 *
 * Returns: `true` if the given argument is an input stream type.
 */
bool isSomeInputStream(StreamType)() {
    // Note: We use a cascading static check style so the compiler runs these checks in this order.
    static if (hasMember!(StreamType, "read")) {
        alias func = StreamType.read;
        static if (isCallable!func && is(ReturnType!func == int)) {
            static if (Parameters!func.length == 1) {
                return isDynamicArray!(Parameters!func[0]);
            } else { return false; }
        } else { return false; }
    } else { return false; }
}

unittest {
    struct S1 {
        int read(ubyte[] buffer) { return 0; }
    }
    assert(isSomeInputStream!S1);
    struct S2 {
        int read(bool[] buffer) { return 42; }
    }
    assert(isSomeInputStream!S2);
    struct S3 {
        int read(bool[] buffer, int otherArg) { return 0; }
    }
    assert(!isSomeInputStream!S3);
    struct S4 {
        void read(long[] buffer) {}
    }
    assert(!isSomeInputStream!S4);
    struct S5 {
        int read = 10;
    }
    assert(!isSomeInputStream!S5);
    struct S6 {}
    assert(!isSomeInputStream!S6);
    interface I1 {
        int read(ubyte[] buffer);
    }
    assert(isSomeInputStream!I1);
    class C1 {
        int read(ubyte[] buffer) { return 0; }
    }
    assert(isSomeInputStream!C1);
}

/** 
 * Determines if the given template argument is some form of output stream,
 * where an output stream is anything with a `write` method that takes a single
 * array parameter, and returns an integer number of elements that were read,
 * or -1 in case of error. This method does not care about the type of elements
 * that can be read by the stream.
 *
 * Returns: `true` if the given argument is an output stream type.
 */
bool isSomeOutputStream(StreamType)() {
    // Note: We use a cascading static check style so the compiler runs these checks in this order.
    static if (hasMember!(StreamType, "write")) {
        alias func = StreamType.write;
        static if (isCallable!func && is(ReturnType!func == int)) {
            static if (Parameters!func.length == 1) {
                return isDynamicArray!(Parameters!func[0]);
            } else { return false; }
        } else { return false; }
    } else { return false; }
}

unittest {
    struct S1 {
        int write(ubyte[] buffer) { return 0; }
    }
    assert(isSomeOutputStream!S1);
    struct S2 {
        int write(bool[] buffer) { return 42; }
    }
    assert(isSomeOutputStream!S2);
    struct S3 {
        int write(bool[] buffer, int otherArg) { return 0; }
    }
    assert(!isSomeOutputStream!S3);
    struct S4 {
        void write(long[] buffer) {}
    }
    assert(!isSomeOutputStream!S4);
    struct S5 {
        int write = 10;
    }
    assert(!isSomeOutputStream!S5);
    struct S6 {}
    assert(!isSomeOutputStream!S6);
}

/** 
 * Determines if the given stream type is an input stream for reading data of
 * the given type.
 * Returns: `true` if the given stream type is an input stream.
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
        int read(ubyte[] buffer) {
            return 0; // Don't do anything with the data.
        }
    }
    assert(isInputStream!(S1, ubyte));

    // Test a few invalid input streams.
    struct S2 {}
    assert(!isInputStream!(S2, ubyte));
    struct S3 {
        void read(ubyte[] buffer) {
            // Invalid return type!
        }
    }
    assert(!isInputStream!(S3, ubyte));
    struct S4 {
        int read() {
            return 0; // Missing required arguments.
        }
    }
    assert(!isInputStream!(S4, ubyte));
    class C1 {
        int read(char[] buffer) {
            return 0;
        }
    }
    assert(isInputStream!(C1, char));
}

/** 
 * Determines if the given stream type is an output stream for writing data of
 * the given type.
 * Returns: `true` if the given stream type is an output stream.
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
        int write(ref ubyte[] buffer) {
            return 0; // Don't do anything with the data.
        }
    }
    assert(isOutputStream!(S1, ubyte));

    // Test a few invalid output streams.
    struct S2 {}
    assert(!isOutputStream!(S2, ubyte));
    struct S3 {
        void write(ubyte[] buffer) {
            // Invalid return type!
        }
    }
    assert(!isOutputStream!(S3, ubyte));
    struct S4 {
        int write() {
            return 0; // Missing required arguments.
        }
    }
    assert(!isOutputStream!(S4, ubyte));
}

/** 
 * Wraps an existing output stream as a Phobos-style output range with a
 * `put` method, to make any output stream compatible with functions that take
 * output ranges. The given stream is stored as a pointer in the underlying
 * range implementation, so you should still manage ownership of the original
 * stream.
 * Params:
 *   stream = The stream to wrap.
 */
auto asOutputRange(E, S)(ref S stream) if (isOutputStream!(S, E)) {
    struct StreamOutputRange {
        private S* stream;
        
        void put(E[] buffer) {
            this.stream.write(buffer);
        }
    }
    return StreamOutputRange(&stream);
}

unittest {
    import streams;
    auto s = ArrayOutputStream!ubyte();
    auto o = asOutputRange!ubyte(s);
    assert(isOutputRange!(typeof(o), ubyte));
}

/** 
 * Determines if the given template argument is a stream of any kind; that is,
 * it is at least implementing the functions required to be an input or output
 * stream.
 * Returns: `true` if the given argument is some stream.
 */
bool isSomeStream(StreamType)() {
    return isSomeInputStream!StreamType || isSomeOutputStream!StreamType;
}

unittest {
    struct S1 {
        int read(ubyte[] buffer) {
            return 0;
        }
    }
    assert(isSomeStream!S1);
    struct S2 {
        int write(ubyte[] buffer) {
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
 * Returns: `true` if the stream type is an input or output stream for the given data type.
 */
bool isSomeStream(StreamType, DataType)() {
    return isInputStream!(StreamType, DataType) || isOutputStream(StreamType, DataType);
}

/** 
 * Determines if the given stream type is an input stream for `ubyte` elements.
 * Returns: `true` if the stream type is a byte input stream.
 */
bool isByteInputStream(StreamType)() {
    return isInputStream!(StreamType, ubyte);
}

/** 
 * Determines if the given stream type is an output stream for `ubyte` elements.
 * Returns: `true` if the stream type is a byte output stream.
 */
bool isByteOutputStream(StreamType)() {
    return isOutputStream!(StreamType, ubyte);
}

/** 
 * Determines if the given template argument is a closable stream type, which
 * defines a `void close()` method as a means to close and/or deallocate the
 * underlying resource that the stream reads from or writes to.
 *
 * Returns: `true` if the given argument is a closable stream.
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
        int read(ubyte[] buffer) {
            return 0;
        }
        void close() {}
    }
    assert(isClosableStream!S1);
    struct S2 {
        int read(ubyte[] buffer) {
            return 0;
        }
    }
    assert(!isClosableStream!S2);
    struct S3 {}
    assert(!isClosableStream!S3);
}

/** 
 * Determines if the given template argument is a flushable stream type, which
 * is any output stream that defines a `void flush()` method, which should
 * cause any data buffered by the stream or its resources to be flushed. The
 * exact nature of how a flush operates is implementation-dependent.
 *
 * Returns: `true` if the given argument is a flushable stream.
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
        int write(ubyte[] buffer) {
            return 0;
        }
        void flush() {}
    }
    assert(isFlushableStream!S1);
    struct S2 {
        int write(ubyte[] buffer) {
            return 0;
        }
    }
    assert(!isFlushableStream!S2);
    struct S3 {}
    assert(!isFlushableStream!S3);
}

/** 
 * An exception that may be thrown if an illegal operation or error occurs
 * while working with streams. Generally, if an exception is to be thrown while
 * reading or writing in a stream's implementation, a `StreamException` should
 * be wrapped around it to provide a common interface for error handling.
 */
class StreamException : Exception {
    import std.exception;

    mixin basicExceptionCtors;
}
