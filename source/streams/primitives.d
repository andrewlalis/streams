/**
 * A collection of compile-time functions to help in identifying stream types
 * and related flavors of them.
 *
 * Streams come in two main flavors: ${B input} and ${B output} streams.
 * 
 * ${B Input streams} are defined by the presence of a read function:
 * ```d
 * StreamResult readFromStream(DataType[] buffer)
 * ```
 *
 * ${B Output streams} are defined by the presence of a write function:
 * ```d
 * StreamResult writeToStream(DataType[] buffer)
 * ```
 *
 * Usually these functions can be used as [Template Constraints](https://dlang.org/spec/template.html#template_constraints)
 * when defining your own functions and symbols to work with streams.
 * ```d
 * void useBytes(S)(S stream) if (isInputStream!(S, ubyte)) {
 *     ubyte[8192] buffer;
 *     StreamResult result = stream.readFromStream(buffer);
 *     if (!result.hasError) {
 *       // Do something with the data.
 *     }
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
 *
 * As an instance of `Either`, it offers the following methods:
 * - `result.hasError` to check if the result has an error.
 * - `result.hasCount` to check if the result has an element count.
 * - `result.error` to get the `StreamError` instance, if `result.hasError` returns `true`.
 * - `result.count` to get the number of elements read or written, if `result.hasCount` returns `true`.
 */
alias StreamResult = Either!(uint, "count", StreamError, "error");

/** 
 * Determines if the given template argument is some form of input stream.
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
    // Check that pointers to streams are also considered as streams.
    assert(isSomeInputStream!(S1*));
    // But double or triple pointers (or anything else) are not!
    assert(!isSomeInputStream!(S1**));
    assert(!isSomeInputStream!(S1***));
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
 * Determines if the given template argument is some form of output stream.
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
    // Check that pointers to output streams are also considered streams (but not double and so on).
    assert(isSomeOutputStream!(S1*));
    assert(!isSomeOutputStream!(S1**));
    assert(!isSomeOutputStream!(S1***));
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
    assert(is(StreamType!(S1*) == bool));
}

/**
 * A template that evaluates to the base, or lowest level of a given input or
 * output stream, which may be useful when a stream is wrapped by many
 * decorator stream types.
 * Params:
 *   S = The stream to get the base type of.
 *
 * For example, suppose you have the following:
 * ---
 * auto base = arrayInputStreamFor!ubyte([1, 2, 3]);
 * auto wrapped = bufferedInputStreamFor(base);
 * assert(is(BaseStreamType!(typeof(wrapped)) == ArrayInputStream!ubyte));
 * ---
 */
template BaseStreamType(S) if (isSomeStream!S) {
    // Note: This works based on the convention that all "wrapper" stream
    // types have a single member named "stream".
    static if (__traits(hasMember, S, "stream")) {
        alias BaseStreamType = BaseStreamType!(typeof(__traits(getMember, S, "stream")));
    } else {
        alias BaseStreamType = S;
    }
}

unittest {
    import streams;
    ubyte[3] data = [1, 2, 3];
    ArrayInputStream!ubyte baseInputStream = arrayInputStreamFor!ubyte(data);
    auto wrapped = dataInputStreamFor(bufferedInputStreamFor(baseInputStream));
    assert(is(BaseStreamType!(typeof(wrapped)) == ArrayInputStream!ubyte));
    // Check that base types resolve to themselves.
    assert(is(BaseStreamType!(typeof(baseInputStream)) == ArrayInputStream!ubyte));
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
 * Returns: `true` if the stream type is an input or output stream for the
 * given data type.
 */
bool isSomeStream(StreamType, DataType)() {
    return isInputStream!(StreamType, DataType) || isOutputStream!(StreamType, DataType);
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
 * defines a `Optional!StreamError closeStream()` method as a means to close
 * and/or deallocate the underlying resource that the stream reads from or
 * writes to.
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
    assert(isClosableStream!(S1*));
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
 * is any output stream that defines a `Optional!StreamError flushStream()`
 * method, which should cause any data buffered by the stream or its resources
 * to be flushed. The exact nature of how a flush operates is implementation-
 * dependent.
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
    assert(isFlushableStream!(S1*));
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
 * is any stream, input or output, that defines a `Optional!StreamError seekInStream(ulong offset)`
 * function for seeking to a particular position in a stream, specified by the
 * `offset` in terms of elements.
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
        return (
            is(ReturnType!seekFunction == OptionalStreamError) &&
            params.length == 1 && is(params[0] == ulong)
        );
    } else {
        return false;
    }
}

/**
 * Determines if the given template argument is a pointer to a stream.
 * Returns: `true` if the given argument is a pointer to a stream.
 */
bool isPointerToStream(S)() {
    return is(S == B*, B) && isSomeStream!S;
}

unittest {
    struct S1 {
        StreamResult readFromStream(ubyte[] buf) {
            return StreamResult(0); // cov-ignore
        }
    }
    struct S2 {
        void doStuff() {} // cov-ignore
    }
    assert(isPointerToStream!(S1*));
    assert(!isPointerToStream!S1);
    assert(!isPointerToStream!(S1**));
    assert(!isPointerToStream!(S2*));
}

/** 
 * Determines if the given template argument is a direct stream type, and that
 * it is not a pointer. If true, then this implies that the caller "owns" the
 * stream, and the stream should not be used outside of owner's scope.
 * Returns: `true` if the given argument is a stream, and not a pointer to one.
 */
bool isNonPointerStream(S)() {
    return !is(S == B*, B) && isSomeStream!S;
}

unittest {
    struct S1 {
        StreamResult readFromStream(ubyte[] buf) {
            return StreamResult(0); // cov-ignore
        }
    }
    struct S2 {
        void doStuff() {} // cov-ignore
    }
    assert(isNonPointerStream!(S1));
    assert(!isNonPointerStream!(S1*));
    assert(!isNonPointerStream!(S1**));
    assert(!isNonPointerStream!(S2*));
    assert(!isNonPointerStream!S2);
}

/** 
 * An input stream that always reads 0 elements.
 */
struct NoOpInputStream(T) {
    /** 
     * Reads zero elements.
     * Params:
     *   buffer = A buffer.
     * Returns: Always 0.
     */
    StreamResult readFromStream(T[] buffer) {
        return StreamResult(0);
    }
}

/** 
 * An output stream that always writes 0 elements.
 */
struct NoOpOutputStream(T) {
    /** 
     * Writes zero elements.
     * Params:
     *   buffer = A buffer.
     * Returns: Always 0.
     */
    StreamResult writeToStream(T[] buffer) {
        return StreamResult(0);
    }
}

/** 
 * An input stream that always returns an error response.
 */
struct ErrorInputStream(T) {
    /**
     * Always emits an error response when called.
     * Params:
     *   buffer = A buffer.
     * Returns: A stream error.
     */
    StreamResult readFromStream(T[] buffer) {
        return StreamResult(StreamError("An error occurred.", -1));
    }
}

/** 
 * An output stream that always returns an error response.
 */
struct ErrorOutputStream(T) {
    /**
     * Always emits an error response when called.
     * Params:
     *   buffer = A buffer.
     * Returns: A stream error.
     */
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
