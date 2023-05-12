module streams.primitives;

import std.traits;

/** 
 * Determines if the given template argument is some form of input stream, such
 * that it offers a `read` function where `DataType` is any type:
 * ```d
 * int read(ref DataType[] buffer, uint offset, uint length)
 * ```
 * Returns: True if the given argument is an input stream type, or false otherwise.
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

/** 
 * Determines if the given template argument is some form of output stream,
 * such that it offers a `write` function where `DataType` is any type:
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
 * Determines if the given template argument is an input stream type; that is,
 * one with a function like so:
 * ```d
 * int read(ref ubyte[] buffer, uint offset, uint count)
 * ```
 * Returns: True if the given argument is an input stream, or false otherwise.
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
 * Determines if the given template argument is an output stream type; that is,
 * one with a function like so:
 *
 * ```d
 * int write(ref ubyte[] buffer, uint offset, uint count)
 * ```
 * Returns: True if the given argument is an output stream, or false otherwise.
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

bool isSomeStream(StreamType, DataType)() {
    return isInputStream!(StreamType, DataType) || isOutputStream(StreamType, DataType);
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
