/**
 * A collection of compile-time functions to help in identifying stream types
 * and related flavors of them.
 *
 * Streams come in two main flavors: ${B input} and ${B output} streams.
 * 
 * ${B Input streams} are defined by the presence of a read function:
 * ```d
 * int readFromStream(DataType[] buffer)
 * ```
 *
 * ${B Output streams} are defined by the presence of a write function:
 * ```d
 * int writeToStream(DataType[] buffer)
 * ```
 *
 * Usually these functions can be used as [Template Constraints](https://dlang.org/spec/template.html#template_constraints)
 * when defining your own functions and symbols to work with streams.
 * ```d
 * void useBytes(S)(S stream) if (isInputStream!(S, ubyte)) {
 *     ubyte[8192] buffer;
 *     int bytesRead = stream.readFromStream(buffer);
 *     // Do something with the data.
 * }
 * ```
 */
module streams.primitives;

import streams.utils : Optional, Either;
import std.range : ElementType;
import std.traits : isCallable, ReturnType, Parameters, isDynamicArray;

private const INPUT_STREAM_METHOD = "readFromStream";
private const OUTPUT_STREAM_METHOD = "writeToStream";
private const FLUSHABLE_STREAM_METHOD = "flushStream";
private const CLOSABLE_STREAM_METHOD = "closeStream";
private const SEEKABLE_STREAM_METHOD = "seekInStream";

/**
 * An error that occurred during a stream operation, which includes a short
 * message, as well as an integer code which is usually the last stream
 * operation return code.
 */
struct StreamError {
    const(char[]) message;
    const int code;
}

/**
 * A convenience alias for an optional stream error, which is a common return
 * type for many stream methods.
 */
alias OptionalStreamError = Optional!StreamError;

/**
 * Either a number of items that have been read or written, or a stream error,
 * as a common result type for many stream operations.
 */
alias StreamResult = Either!(uint, "count", StreamError, "error");

/** 
 * Determines if the given template argument is some form of input stream,
 * where an input stream is anything with a read method that takes a single
 * array parameter, and returns an integer number of elements that were read,
 * or -1 in case of error. This method does not care about the type of elements
 * that can be read by the stream.
 *
 * Returns: `true` if the given argument is an input stream type.
 */
bool isSomeInputStream(StreamType)() {
    // Note: We use a cascading static check style so the compiler runs these checks in this order.
    static if (__traits(hasMember, StreamType, INPUT_STREAM_METHOD)) {
        alias func = __traits(getMember, StreamType, INPUT_STREAM_METHOD);
        static if (isCallable!func && is(ReturnType!func == StreamResult)) {
            static if (Parameters!func.length == 1) {
                return isDynamicArray!(Parameters!func[0]);
            } else { return false; }
        } else { return false; }
    } else { return false; }
}

unittest {
    struct S1 {
        StreamResult readFromStream(ubyte[] buffer) { return StreamResult(0); } // cov-ignore
    }
    assert(isSomeInputStream!S1);
    struct S2 {
        StreamResult readFromStream(bool[] buffer) { return StreamResult(42); } // cov-ignore
    }
    assert(isSomeInputStream!S2);
    struct S3 {
        StreamResult readFromStream(bool[] buffer, int otherArg) { return StreamResult(0); } // cov-ignore
    }
    assert(!isSomeInputStream!S3);
    struct S4 {
        void readFromStream(long[] buffer) {}
    }
    assert(!isSomeInputStream!S4);
    struct S5 {
        StreamResult readFromStream = StreamResult(10);
    }
    assert(!isSomeInputStream!S5);
    struct S6 {}
    assert(!isSomeInputStream!S6);
    
    version (D_BetterC) {} else {
        interface I1 {
            StreamResult readFromStream(ubyte[] buffer);
        }
        assert(isSomeInputStream!I1);
        class C1 {
            StreamResult readFromStream(ubyte[] buffer) { return StreamResult(0); } // cov-ignore
        }
        assert(isSomeInputStream!C1);
    }
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
    static if (__traits(hasMember, StreamType, OUTPUT_STREAM_METHOD)) {
        alias func = __traits(getMember, StreamType, OUTPUT_STREAM_METHOD);
        static if (isCallable!func && is(ReturnType!func == StreamResult)) {
            static if (Parameters!func.length == 1) {
                return isDynamicArray!(Parameters!func[0]);
            } else { return false; }
        } else { return false; }
    } else { return false; }
}

unittest {
    struct S1 {
        StreamResult writeToStream(ubyte[] buffer) { return StreamResult(0); } // cov-ignore
    }
    assert(isSomeOutputStream!S1);
    struct S2 {
        StreamResult writeToStream(bool[] buffer) { return StreamResult(42); } // cov-ignore
    }
    assert(isSomeOutputStream!S2);
    struct S3 {
        StreamResult writeToStream(bool[] buffer, int otherArg) { return StreamResult(0); } // cov-ignore
    }
    assert(!isSomeOutputStream!S3);
    struct S4 {
        void writeToStream(long[] buffer) {}
    }
    assert(!isSomeOutputStream!S4);
    struct S5 {
        StreamResult writeToStream = StreamResult(10);
    }
    assert(!isSomeOutputStream!S5);
    struct S6 {}
    assert(!isSomeOutputStream!S6);
}

/** 
 * A template that evaluates to the type of a given input or output stream.
 * Params:
 *   S = The stream to get the type of.
 */
template StreamType(S) if (isSomeStream!S) {
    static if (isSomeInputStream!S) {
        alias StreamType = ElementType!(Parameters!(__traits(getMember, S, INPUT_STREAM_METHOD))[0]);
    } else {
        alias StreamType = ElementType!(Parameters!(__traits(getMember, S, OUTPUT_STREAM_METHOD))[0]);
    }
}

unittest {
    struct S1 {
        StreamResult readFromStream(bool[] buffer) {
            return StreamResult(0); // cov-ignore
        }
    }
    assert(is(StreamType!S1 == bool));
}

/** 
 * Determines if the given stream type is an input stream for reading data of
 * the given type.
 * Returns: `true` if the given stream type is an input stream.
 */
bool isInputStream(StreamType, DataType)() {
    static if (isSomeInputStream!StreamType) {
        return is(Parameters!(__traits(getMember, StreamType, INPUT_STREAM_METHOD))[0] == DataType[]);
    } else {
        return false;
    }
}

unittest {
    // Test a valid input stream.
    struct S1 {
        StreamResult readFromStream(ubyte[] buffer) {
            return StreamResult(0); // cov-ignore
        }
    }
    assert(isInputStream!(S1, ubyte));

    // Test a few invalid input streams.
    struct S2 {}
    assert(!isInputStream!(S2, ubyte));
    struct S3 {
        void readFromStream(ubyte[] buffer) {
            // Invalid return type!
        }
    }
    assert(!isInputStream!(S3, ubyte));
    struct S4 {
        StreamResult readFromStream() {
            return StreamResult(0); // cov-ignore
        }
    }
    assert(!isInputStream!(S4, ubyte));

    version (D_BetterC) {} else {
        class C1 {
            StreamResult readFromStream(char[] buffer) {
                return StreamResult(0); // cov-ignore
            }
        }
        assert(isInputStream!(C1, char));
    }
}

/** 
 * Determines if the given stream type is an output stream for writing data of
 * the given type.
 * Returns: `true` if the given stream type is an output stream.
 */
bool isOutputStream(StreamType, DataType)() {
    static if (isSomeOutputStream!StreamType) {
        return is(Parameters!(__traits(getMember, StreamType, OUTPUT_STREAM_METHOD))[0] == DataType[]);
    } else {
        return false;
    }
}

unittest {
    // Test a valid output stream.
    struct S1 {
        StreamResult writeToStream(ref ubyte[] buffer) {
            return StreamResult(0); // cov-ignore
        }
    }
    assert(isOutputStream!(S1, ubyte));

    // Test a few invalid output streams.
    struct S2 {}
    assert(!isOutputStream!(S2, ubyte));
    struct S3 {
        void writeToStream(ubyte[] buffer) {
            // Invalid return type!
        }
    }
    assert(!isOutputStream!(S3, ubyte));
    struct S4 {
        StreamResult writeToStream() {
            return StreamResult(0); // cov-ignore
        }
    }
    assert(!isOutputStream!(S4, ubyte));
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
        StreamResult readFromStream(ubyte[] buffer) {
            return StreamResult(0); // cov-ignore
        }
    }
    assert(isSomeStream!S1);
    struct S2 {
        StreamResult writeToStream(ubyte[] buffer) {
            return StreamResult(0); // cov-ignore
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
 * defines a `void closeStream()` method as a means to close and/or deallocate
 * the underlying resource that the stream reads from or writes to.
 *
 * Returns: `true` if the given argument is a closable stream.
 */
bool isClosableStream(S)() {
    static if (
        isSomeStream!S &&
        __traits(hasMember, S, CLOSABLE_STREAM_METHOD) &&
        isCallable!(__traits(getMember, S, CLOSABLE_STREAM_METHOD))
    ) {
        alias closeFunction = __traits(getMember, S, CLOSABLE_STREAM_METHOD);
        alias params = Parameters!closeFunction;
        return (is(ReturnType!closeFunction == OptionalStreamError) && params.length == 0);
    } else {
        return false;
    }
}

unittest {
    struct S1 {
        StreamResult readFromStream(ubyte[] buffer) {
            return StreamResult(0); // cov-ignore
        }
        OptionalStreamError closeStream() {
            return OptionalStreamError.init; // cov-ignore
        }
    }
    assert(isClosableStream!S1);
    struct S2 {
        StreamResult readFromStream(ubyte[] buffer) {
            return StreamResult(0); // cov-ignore
        }
    }
    assert(!isClosableStream!S2);
    struct S3 {}
    assert(!isClosableStream!S3);
}

/** 
 * Determines if the given template argument is a flushable stream type, which
 * is any output stream that defines a `void flushStream()` method, which should
 * cause any data buffered by the stream or its resources to be flushed. The
 * exact nature of how a flush operates is implementation-dependent.
 *
 * Returns: `true` if the given argument is a flushable stream.
 */
bool isFlushableStream(S)() {
    static if (
        isSomeOutputStream!S &&
        __traits(hasMember, S, FLUSHABLE_STREAM_METHOD) &&
        isCallable!(__traits(getMember, S, FLUSHABLE_STREAM_METHOD))
    ) {
        alias flushFunction = __traits(getMember, S, FLUSHABLE_STREAM_METHOD);
        alias params = Parameters!flushFunction;
        return (is(ReturnType!flushFunction == OptionalStreamError) && params.length == 0);
    } else {
        return false;
    }
}

unittest {
    struct S1 {
        StreamResult writeToStream(ubyte[] buffer) {
            return StreamResult(0); // cov-ignore
        }
        OptionalStreamError flushStream() {
            return OptionalStreamError.init; // cov-ignore
        }
    }
    assert(isFlushableStream!S1);
    struct S2 {
        StreamResult writeToStream(ubyte[] buffer) {
            return StreamResult(0); // cov-ignore
        }
    }
    assert(!isFlushableStream!S2);
    struct S3 {}
    assert(!isFlushableStream!S3);
}

/** 
 * Determines if the given template argument is a seekable stream type, which
 * is any stream, input or output, that defines a `seekInStream()` method that
 * causes the stream to seek to a particular location in the underlying
 * resource so that the next stream operation takes place from that location.
 * Returns: `true` if the given argument is a seekable stream.
 */
bool isSeekableStream(S)() {
    static if (
        isSomeStream!S &&
        __traits(hasMember, S, SEEKABLE_STREAM_METHOD) &&
        isCallable!(__traits(getMember, S, SEEKABLE_STREAM_METHOD))
    ) {
        alias seekFunction = __traits(getMember, S, SEEKABLE_STREAM_METHOD);
        alias params = Parameters!seekFunction;
        return (is(ReturnType!seekFunction == void) && params.length == 0);
    } else {
        return false;
    }
}

/** 
 * An input stream that always reads 0 elements.
 */
struct NoOpInputStream(T) {
    StreamResult readFromStream(T[] buffer) {
        return StreamResult(0);
    }
}

/** 
 * An output stream that always writes 0 elements.
 */
struct NoOpOutputStream(T) {
    StreamResult writeToStream(T[] buffer) {
        return StreamResult(0);
    }
}

/** 
 * An input stream that always returns a -1 error response.
 */
struct ErrorInputStream(T) {
    StreamResult readFromStream(T[] buffer) {
        return StreamResult(StreamError("An error occurred.", -1));
    }
}

/** 
 * An output stream that always returns a -1 error response.
 */
struct ErrorOutputStream(T) {
    StreamResult writeToStream(T[] buffer) {
        return StreamResult(StreamError("An error occurred.", -1));
    }
}

unittest {
    auto s1 = NoOpInputStream!ubyte();
    ubyte[3] buffer;
    assert(s1.readFromStream(buffer) == StreamResult(0));
    assert(buffer == [0, 0, 0]);
    
    auto s2 = NoOpOutputStream!ubyte();
    assert(s2.writeToStream(buffer) == StreamResult(0));

    auto s3 = ErrorInputStream!ubyte();
    assert(s3.readFromStream(buffer).hasError);

    auto s4 = ErrorOutputStream!ubyte();
    assert(s4.writeToStream(buffer).hasError);
}
