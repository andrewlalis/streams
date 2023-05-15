/**
 * Defines some components that provide interoperability with Phobos ranges,
 * including converting streams to and from ranges.
 */
module streams.range;

import streams.primitives;
import std.range;

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
    struct InputStreamRange {
        import std.typecons;

        private S* stream;
        private Nullable!E lastElement;
        private int lastRead;

        this(ref S stream) {
            this.stream = &stream;
            // Initialize the range with one element.
            this.popFront();
        }

        void popFront() {
            E[1] buffer;
            this.lastRead = this.stream.read(buffer);
            if (this.lastRead > 0) {
                this.lastElement = nullable(buffer[0]);
            } else {
                this.lastElement = Nullable!E.init;
            }
        }

        bool empty() {
            return this.lastRead < 1;
        }

        E front() {
            return this.lastElement.get();
        }
    }
    return InputStreamRange(stream);
}

unittest {
    import streams;
    auto s = arrayInputStreamFor!ubyte([1, 2, 3]);
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
 * Wraps a Phobos-style input range as an input stream.
 * Params:
 *   range = The range to wrap in an input stream.
 * Returns: An input stream that reads data from the underlying input range.
 */
auto asInputStream(R, E = ElementType!R)(R range) if (isInputRange!R) {
    struct InputRangeStream {
        private R range;

        int read(E[] buffer) {
            int readCount = 0;
            while (readCount < buffer.length && !this.range.empty()) {
                E element = this.range.front();
                buffer[readCount++] = element;
                this.range.popFront();
            }
            return readCount;
        }
    }
    return InputRangeStream(range);
}

unittest {
    int[] r = [1, 2, 3, 4, 5, 6];
    auto s = asInputStream(r);
    int[] buffer = new int[4];
    assert(s.read(buffer) == 4);
    assert(buffer == [1, 2, 3, 4]);

    auto s2 = asInputStream("Hello world");
    dchar[] buffer2 = new dchar[4];
    assert(s2.read(buffer2) == 4);
    assert(buffer2 == "Hell");
    assert(s2.read(buffer2) == 4);
    assert(buffer2 == "o wo");
    assert(s2.read(buffer2) == 3);
    assert(buffer2 == "rldo");
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
    auto s = arrayOutputStreamFor!ubyte;
    auto o = asOutputRange(s);
    assert(isOutputRange!(typeof(o), ubyte));
    assert(s.toArray() == []);
    o.put([1, 2, 3]);
    assert(s.toArray() == [1, 2, 3]);
}

/** 
 * Wraps a Phobos-style output range as an output stream.
 * Params:
 *   range = The output range to wrap.
 * Returns: An output stream that writes data to the underlying output range.
 */
auto asOutputStream(R, E = ElementType!R)(R range) if (isOutputRange!(R, E)) {
    struct OutputRangeStream {
        private R range;

        int write(E[] buffer) {
            this.range.put(buffer);
            return cast(int) buffer.length;
        }
    }
    return OutputRangeStream(range);
}

unittest {
    ubyte[] r = new ubyte[8192];
    auto s = asOutputStream(r);
    assert(s.write([1, 2, 3]) == 3);
    assert(r[0 .. 3] == [1, 2, 3]);
    assert(s.write([4, 5]) == 2);
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
    import streams;
    
    int[] inputRange = new int[10];
    auto inputStream = asStream(inputRange);
    assert(isInputStream!(typeof(inputStream), int));
    // First check that something which is both an input and output range defaults to input stream.
    int[] outputRange;
    auto outputStream = asStream(outputRange);
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
    import streams;

    auto inputStream = arrayInputStreamFor!ubyte([1, 2, 3]);
    auto inputRange = asRange(inputStream);
    assert(isInputRange!(typeof(inputRange)));
    assert(is(ElementType!(typeof(inputRange)) == ubyte));

    auto outputStream = byteArrayOutputStream();
    auto outputRange = asRange(outputStream);
    assert(isOutputRange!(typeof(outputRange), ubyte));
}