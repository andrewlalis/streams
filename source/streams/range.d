/**
 * Defines some components that provide interoperability with Phobos ranges,
 * including converting streams to and from ranges.
 */
module streams.range;

import streams.primitives : StreamType, isInputStream, isSomeInputStream, isOutputStream, isSomeStream;
import streams.utils : Optional;
import std.range : isInputRange, isOutputRange, ElementType, empty, front, popFront, put;

/** 
 * A struct that, when initialized with an input stream, acts as a Phobos-style
 * input range for elements of the same type.
 */
struct InputStreamRange(S, E = StreamType!S) if (isInputStream!(S, E)) {
    private S* stream;
    private Optional!E lastElement;
    private int lastRead;

    this(ref S stream) {
        this.stream = &stream;
        // Initialize the range with one element.
        this.popFront();
    }

    void popFront() {
        E[1] buffer;
        this.lastRead = this.stream.readFromStream(buffer);
        if (this.lastRead > 0) {
            this.lastElement = Optional!E(buffer[0]);
        } else {
            this.lastElement = Optional!E.init;
        }
    }

    bool empty() {
        return this.lastRead < 1;
    }

    E front() {
        return this.lastElement.value;
    }
}

/** 
 * Wraps an existing input stream as a Phobos-style input range, to make any
 * input stream compatible with functions that take input ranges. The given
 * stream is stored as a pointer in the underlying range implementation, so you
 * should still manage ownership of the original stream.
 * 
 * ```d
 * import std.range.primitives : isInputRange;
 * import streams;
 *
 * auto stream = inputStreamFor!int([1, 2, 3]);
 * auto range = asInputRange!int(stream);
 * assert(isInputRange!(typeof(range)));
 * ```
 * Params:
 *   stream = The stream to wrap.
 * Returns: The input range.
 */
auto asInputRange(S, E = StreamType!S)(ref S stream) if (isInputStream!(S, E)) {
    return InputStreamRange!(S, E)(stream);
}

unittest {
    import streams : arrayInputStreamFor;
    ubyte[3] buf = [1, 2, 3];
    auto s = arrayInputStreamFor(buf);
    auto r = asInputRange(s);
    assert(isInputRange!(typeof(r)));
    assert(!r.empty());
    assert(r.front() == 1);
    r.popFront();
    assert(!r.empty());
    assert(r.front() == 2);
    r.popFront();
    assert(!r.empty());
    assert(r.front() == 3);
    r.popFront();
    assert(r.empty());
}

/** 
 * An input stream implementation that wraps around a Phobos-style input range.
 */
struct InputRangeStream(R, E = ElementType!R) if (isInputRange!R) {
    private R range;

    int readFromStream(E[] buffer) {
        int readCount = 0;
        while (readCount < buffer.length && !this.range.empty()) {
            E element = this.range.front();
            buffer[readCount++] = element;
            this.range.popFront();
        }
        return readCount;
    }
}

/** 
 * Wraps a Phobos-style input range as an input stream.
 * Params:
 *   range = The range to wrap in an input stream.
 * Returns: An input stream that reads data from the underlying input range.
 */
auto asInputStream(R, E = ElementType!R)(R range) if (isInputRange!R) {
    return InputRangeStream!(R, E)(range);
}

// TODO: Fix these tests!!!
// unittest {
//     int[6] r = [1, 2, 3, 4, 5, 6];
//     auto s = asInputStream(r[]);
//     int[4] buffer;
//     assert(s.readFromStream(buffer) == 4);
//     assert(buffer == [1, 2, 3, 4]);

//     auto s2 = asInputStream("Hello world");
//     dchar[4] buffer2;
//     assert(s2.readFromStream(buffer2) == 4);
//     assert(buffer2 == "Hell");
//     assert(s2.readFromStream(buffer2) == 4);
//     assert(buffer2 == "o wo");
//     assert(s2.readFromStream(buffer2) == 3);
//     assert(buffer2 == "rldo");
// }

/** 
 * A struct that, when initialized with an output stream, acts as a Phobos-
 * style output range for elements of the same type.
 */
struct OutputStreamRange(S, E = StreamType!S) if (isOutputStream!(S, E)) {
    private S* stream;
    
    void put(E[] buffer) {
        this.stream.writeToStream(buffer);
    }
}

/** 
 * Wraps an existing output stream as a Phobos-style output range with a
 * `put` method, to make any output stream compatible with functions that take
 * output ranges. The given stream is stored as a pointer in the underlying
 * range implementation, so you should still manage ownership of the original
 * stream.
 * 
 * ```d
 * import std.range.primitives : isOutputRange;
 * import streams;
 *
 * auto stream = ArrayOutputStream!int();
 * auto range = asOutputRange!int(stream);
 * assert(isOutputRange!(typeof(range), int));
 * ```
 * Params:
 *   stream = The stream to wrap.
 * Returns: The output range.
 */
auto asOutputRange(S, E = StreamType!S)(ref S stream) if (isOutputStream!(S, E)) {
    return OutputStreamRange!(S, E)(&stream);
}

unittest {
    import streams : arrayOutputStreamFor;
    auto s = arrayOutputStreamFor!ubyte;
    auto o = asOutputRange(s);
    assert(isOutputRange!(typeof(o), ubyte));
    assert(s.toArrayRaw() == []);
    ubyte[3] buf = [1, 2, 3];
    o.put(buf);
    assert(s.toArrayRaw() == [1, 2, 3]);
}

/** 
 * An output stream implementation that wraps a Phobos-style output range.
 */
struct OutputRangeStream(R, E = ElementType!R) if (isOutputRange!(R, E)) {
    private R range;

    int writeToStream(E[] buffer) {
        this.range.put(buffer);
        return cast(int) buffer.length;
    }
}

/** 
 * Wraps a Phobos-style output range as an output stream.
 * Params:
 *   range = The output range to wrap.
 * Returns: An output stream that writes data to the underlying output range.
 */
auto asOutputStream(R, E = ElementType!R)(R range) if (isOutputRange!(R, E)) {
    return OutputRangeStream!(R, E)(range);
}

unittest {
    ubyte[8192] r;
    auto s = asOutputStream(r[]);
    ubyte[3] buf = [1, 2, 3];
    assert(s.writeToStream(buf) == 3);
    assert(r[0 .. 3] == [1, 2, 3]);
    buf[0] = 4;
    buf[1] = 5;
    assert(s.writeToStream(buf[0 .. 2]) == 2);
    assert(r[0 .. 5] == [1, 2, 3, 4, 5]);
}

/** 
 * Converts the given range to a stream. Input ranges are converted to input
 * streams, and output ranges are converted to output streams. Note that if
 * the given range is both an input and an output range, an input stream is
 * returned.
 * Params:
 *   range = The range to convert.
 * Returns: A stream that wraps the given range.
 */
auto asStream(R, E = ElementType!R)(R range) if (isInputRange!R || isOutputRange!(R, E)) {
    static if (isInputRange!R) {
        return asInputStream!(R, E)(range);
    } else {
        return asOutputStream!(R, E)(range);
    }
}

unittest {
    import streams.types.array : byteArrayOutputStream;

    int[10] inputRange;
    auto inputStream = asStream(inputRange[]);
    assert(isInputStream!(typeof(inputStream), int));
    // First check that something which is both an input and output range defaults to input stream.
    int[10] outputRange;
    auto outputStream = asStream(outputRange[]);
    assert(isInputStream!(typeof(outputStream), int));
    // Now check a "pure" output range.
    
    auto sOut = byteArrayOutputStream();
    auto pureOutputRange = asOutputRange(sOut);
    assert(isOutputRange!(typeof(pureOutputRange), ubyte) && !isInputRange!(typeof(pureOutputRange)));
    // We do need to use explicit template arguments here.
    auto pureOutputStream = asStream!(typeof(pureOutputRange), ubyte)(pureOutputRange);
    assert(isOutputStream!(typeof(pureOutputStream), ubyte));
}

/** 
 * Converts the given stream to a range. Input streams are converted to input
 * ranges, and output streams are converted to output ranges.
 * Params:
 *   stream = The stream to convert.
 * Returns: A range that wraps the given stream.
 */
auto asRange(S, E = StreamType!S)(ref S stream) if (isSomeStream!S) {
    static if (isSomeInputStream!S) {
        return asInputRange!(S, E)(stream);
    } else {
        return asOutputRange!(S, E)(stream);
    }
}

unittest {
    import streams.types.array : arrayInputStreamFor, byteArrayOutputStream;

    ubyte[3] buf1 = [1, 2, 3];
    auto inputStream = arrayInputStreamFor(buf1);
    auto inputRange = asRange(inputStream);
    assert(isInputRange!(typeof(inputRange)));
    assert(is(ElementType!(typeof(inputRange)) == ubyte));

    auto outputStream = byteArrayOutputStream();
    auto outputRange = asRange(outputStream);
    assert(isOutputRange!(typeof(outputRange), ubyte));
}
