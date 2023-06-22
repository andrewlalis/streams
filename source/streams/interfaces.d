/** 
 * Object-oriented interfaces and classes for dealing with streams. The symbols
 * defined in this module are only available when not in "BetterC" mode, as
 * they require the use of the Garbage Collector.
 */
module streams.interfaces;

import streams.primitives;

version (D_BetterC) {} else {

/** 
 * Interface defining an input stream object that reads elements from some
 * resource.
 */
interface InputStream(E) {
    /** 
     * Reads elements from a resource and writes them to `buffer`.
     * Params:
     *   buffer = The buffer to read elements into.
     * Returns: The stream result.
     */
    StreamResult readFromStream(E[] buffer);
}

/** 
 * Interface defining an output stream object that writes elements to some
 * resource.
 */
interface OutputStream(E) {
    /** 
     * Writes elements from `buffer` to a resource.
     * Params:
     *   buffer = The buffer containing elements to write.
     * Returns: The stream result.
     */
    StreamResult writeToStream(E[] buffer);
}

/** 
 * Interface defining a stream that is closable.
 */
interface ClosableStream {
    /** 
     * Closes the stream.
     * Returns: An optional stream error, if closing the stream fails.
     */
    OptionalStreamError closeStream();
}

/** 
 * Interface defining a stream that is flushable.
 */
interface FlushableStream {
    /** 
     * Flushes the stream.
     * Returns: An optional stream error, if flushing the stream fails.
     */
    OptionalStreamError flushStream();
}

/** 
 * Input stream implementation that wraps around a primitive input stream.
 */
class InputStreamObject(S, E = StreamType!S) : InputStream!E if (isInputStream!(S, E)) {
    private S stream;

    /**
     * Constructs the input stream wrapper with the given base stream.
     * Params:
     *   stream = The stream to wrap in an object-oriented stream.
     */
    this(S stream) {
        this.stream = stream;
    }

    /** 
     * Reads up to `buffer.length` elements from the wrapped input stream, and
     * writes them to `buffer`.
     * Params:
     *   buffer = The buffer to read elements into.
     * Returns: Either the number of elements read, or a stream error.
     */
    StreamResult readFromStream(E[] buffer) {
        return this.stream.readFromStream(buffer);
    }

    static if (isClosableStream!S) {
        OptionalStreamError closeStream() {
            return this.stream.closeStream();
        }
    }
}

/** 
 * Gets a new object-oriented input stream implementation that wraps the given
 * input stream.
 * Params:
 *   stream = The stream to wrap.
 * Returns: An input stream wrapper object.
 */
InputStreamObject!(S, E) inputStreamObjectFor(S, E = StreamType!S)(S stream) if (isInputStream!(S, E)) {
    return new InputStreamObject!(S, E)(stream);
}

/** 
 * Output stream implementation that wraps around a primitive output stream.
 */
class OutputStreamObject(S, E = StreamType!S) : OutputStream!E if (isOutputStream!(S, E)) {
    private S stream;

    /**
     * Constructs the output stream wrapper with a reference to a primitive
     * output stream.
     * Params:
     *   stream = The stream to wrap in an object-oriented stream.
     */
    this(S stream) {
        this.stream = stream;
    }

    /**
     * Writes up to `buffer.length` elements to the wrapped output stream.
     * Params:
     *   buffer = The buffer to write elements from.
     * Returns: Either the number of elements written, or a stream error.
     */
    StreamResult writeToStream(E[] buffer) {
        return this.stream.writeToStream(buffer);
    }

    static if (isClosableStream!S) {
        OptionalStreamError closeStream() {
            return this.stream.closeStream();
        }
    }

    static if (isFlushableStream!S) {
        OptionalStreamError flushStream() {
            return this.stream.flushStream();
        }
    }
}

/** 
 * Gets a new object-oriented output stream implementation that wraps the given
 * output stream.
 * Params:
 *   stream = The stream to wrap.
 * Returns: An output stream wrapper object.
 */
OutputStreamObject!(S, E) outputStreamObjectFor(S, E = StreamType!S)(S stream) if (isOutputStream!(S, E)) {
    return new OutputStreamObject!(S, E)(stream);
}

unittest {
    import streams;
    // Test input stream wrapper.
    auto sIn1 = arrayInputStreamFor!ubyte([1, 2, 3, 4]);
    auto wrapIn1 = new InputStreamObject!(typeof(&sIn1))(&sIn1);
    ubyte[] buffer1 = new ubyte[4];
    assert(wrapIn1.readFromStream(buffer1) == StreamResult(4));
    assert(buffer1 == [1, 2, 3, 4]);
    // Test using the function to make it easier.
    sIn1.reset();
    wrapIn1 = inputStreamObjectFor(&sIn1);
    assert(wrapIn1.readFromStream(buffer1[0 .. 2]) == StreamResult(2));
    assert(buffer1[0 .. 2] == [1, 2]);

    // Test output stream wrapper.
    auto sOut1 = byteArrayOutputStream();
    auto wrapOut1 = new OutputStreamObject!(typeof(&sOut1))(&sOut1);
    assert(wrapOut1.writeToStream([1]) == StreamResult(1));
    assert(sOut1.toArrayRaw() == [1]);
    wrapOut1 = outputStreamObjectFor(&sOut1);
    assert(wrapOut1.writeToStream([2, 3, 4]) == StreamResult(3));
    assert(sOut1.toArrayRaw() == [1, 2, 3, 4]);
}

}
