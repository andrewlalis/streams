/**
 * Defines some components that provide interoperability with Phobos ranges,
 * including converting streams to and from ranges.
 */
module streams.range;

import streams.primitives;
import streams.utils;
import std.range : isInputRange, isOutputRange, ElementType, empty, front, popFront, put;

/** 
 * A struct that, when initialized with an input stream, acts as a Phobos-style
 * input range for elements of the same type.
 */
struct InputStreamRange(S, E = StreamType!S) if (isInputStream!(S, E)) {
    private S stream;
    private Optional!E lastElement;
    private StreamResult lastRead;

    /** 
     * Constructs this range using a reference to a stream.
     * Params:
     *   stream = The input stream to read from.
     */
    this(S stream) {
        this.stream = stream;
        // Initialize the range with one element.
        this.popFront();
    }

    /** 
     * Pops the last-read element from the stream, and buffers the next one so
     * that calling `front()` will return the next element.
     */
    void popFront() {
        E[1] buffer;
        this.lastRead = this.stream.readFromStream(buffer);
        if (this.lastRead.hasCount && this.lastRead.count > 0) {
            this.lastElement = Optional!E(buffer[0]);
        } else {
            this.lastElement = Optional!E.init;
        }
    }

    /** 
     * Determines if the stream is empty. We consider a stream as empty when
     * reading from it returns a result of 0 elements.
     * Returns: `true` if the underlying stream is empty.
     */
    bool empty() {
        return !this.lastRead.hasCount || this.lastRead.count == 0;
    }

    /** 
     * Gets the last-read element from the stream.
     * Returns: The last-read element from the stream.
     */
    E front() {
        return this.lastElement.value;
    }
}

/** 
 * Wraps an existing input stream as a Phobos-style input range, to make any
 * input stream compatible with functions that take input ranges.
 * Params:
 *   stream = The stream to wrap.
 * Returns: The input range.
 */
auto asInputRange(S, E = StreamType!S)(S stream) if (isInputStream!(S, E)) {
    return InputStreamRange!(S, E)(stream);
}

unittest {
    import streams : arrayInputStreamFor;
    ubyte[3] buf = [1, 2, 3];
    auto r = asInputRange(arrayInputStreamFor(buf));
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

    /**
     * Pops elements from the underlying input range to fill `buffer`.
     * Params:
     *   buffer = The buffer to fill.
     * Returns: The number of items that were read.
     */
    StreamResult readFromStream(E[] buffer) {
        int readCount = 0;
        while (readCount < buffer.length && !this.range.empty()) {
            E element = this.range.front();
            buffer[readCount++] = element;
            this.range.popFront();
        }
        return StreamResult(readCount);
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

unittest {
    float[5] inputRange = [0.25, 0.5, 0.75, 1.0, 1.25];
    auto inputStream = asInputStream(inputRange[]);
    float[2] buffer = [0, 0];
    StreamResult result = inputStream.readFromStream(buffer);
    assert(result.hasCount && result.count == 2);
    result = inputStream.readFromStream(buffer);
    assert(result.hasCount && result.count == 2);
    result = inputStream.readFromStream(buffer);
    assert(result.hasCount && result.count == 1);
    result = inputStream.readFromStream(buffer);
    assert(result.hasCount && result.count == 0);
}

/** 
 * A struct that, when initialized with an output stream, acts as a Phobos-
 * style output range for elements of the same type.
 */
struct OutputStreamRange(S, E = StreamType!S) if (isOutputStream!(S, E)) {
    private S stream;
    
    /**
     * Writes all elements in `buffer` to the underlying stream.
     * Params:
     *   buffer = The buffer of elements to write.
     */
    void put(E[] buffer) {
        this.stream.writeToStream(buffer);
    }
}

/**
 * Wraps an existing output stream as a Phobos-style output range with a
 * `put` method, to make any output stream compatible with functions that take
 * output ranges.
 * Params:
 *   stream = The stream to wrap.
 * Returns: The output range.
 */
auto asOutputRange(S, E = StreamType!S)(S stream) if (isOutputStream!(S, E)) {
    return OutputStreamRange!(S, E)(stream);
}

unittest {
    import streams : arrayOutputStreamFor;
    auto s = arrayOutputStreamFor!ubyte;
    auto o = asOutputRange(&s);
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

    /**
     * Writes the elements in `buffer` to the underlying output range.
     * Params:
     *   buffer = The buffer of elements to write.
     * Returns: Always the number of elements in `buffer`. If the underlying
     * range throws an exception, this will be thrown by this stream.
     */
    StreamResult writeToStream(E[] buffer) {
        this.range.put(buffer);
        return StreamResult(cast(uint) buffer.length);
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
    assert(s.writeToStream(buf) == StreamResult(3));
    assert(r[0 .. 3] == [1, 2, 3]);
    buf[0] = 4;
    buf[1] = 5;
    assert(s.writeToStream(buf[0 .. 2]) == StreamResult(2));
    assert(r[0 .. 5] == [1, 2, 3, 4, 5]);
}

/** 
 * Converts the given range to a stream. Input ranges are converted to input
 * streams, and output ranges are converted to output streams. Note that if
 * the given range is both an input and an output range, an input stream is
 * returned. Use `asInputStream` and `asOutputStream` to choose explicitly.
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
