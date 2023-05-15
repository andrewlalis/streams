/** 
 * Object-oriented interfaces and classes for dealing with streams.
 */
module streams.interfaces;

import streams.primitives;

/** 
 * Interface defining an input stream object that reads elements from some
 * resource.
 */
interface InputStream(DataType) {
    /** 
     * Reads elements from a resource and writes them to `buffer`.
     * Params:
     *   buffer = The buffer to read elements into.
     * Returns: The number of elements that were read, or -1 in case of error.
     */
    int read(DataType[] buffer);
}

/** 
 * Interface defining an output stream object that writes elements to some
 * resource.
 */
interface OutputStream(DataType) {
    /** 
     * Writes elements from `buffer` to a resource.
     * Params:
     *   buffer = The buffer containing elements to write.
     * Returns: The number of elements that were written, or -1 in case of error.
     */
    int write(DataType[] buffer);
}

/** 
 * Interface defining a stream that is closable.
 */
interface ClosableStream {
    void close();
}

/** 
 * Interface defining a stream that is flushable.
 */
interface FlushableStream {
    void flush();
}

/** 
 * Input stream implementation that wraps around a primitive input stream.
 */
class InputStreamWrapper(S, E = StreamType!S) : InputStream!E if (isInputStream!(S, E)) {
    private S* stream;

    this(ref S stream) {
        this.stream = &stream;
    }

    int read(E[] buffer) {
        return this.stream.read(buffer);
    }
}

/** 
 * Gets a new object-oriented input stream implementation that wraps the given
 * input stream.
 * Params:
 *   stream = The stream to wrap.
 * Returns: An input stream wrapper object.
 */
InputStreamWrapper!(S, E) inputStreamWrapperFor(S, E = StreamType!S)(ref S stream) if (isInputStream!(S, E)) {
    return new InputStreamWrapper!(S, E)(stream);
}

/** 
 * Output stream implementation that wraps around a primitive output stream.
 */
class OutputStreamWrapper(S, E = StreamType!S) : OutputStream!E if (isOutputStream!(S, E)) {
    private S* stream;

    this(ref S stream) {
        this.stream = &stream;
    }

    int write(E[] buffer) {
        return this.stream.write(buffer);
    }
}

/** 
 * Gets a new object-oriented output stream implementation that wraps the given
 * output stream.
 * Params:
 *   stream = The stream to wrap.
 * Returns: An output stream wrapper object.
 */
OutputStreamWrapper!(S, E) outputStreamWrapperFor(S, E = StreamType!S)(ref S stream) if (isOutputStream!(S, E)) {
    return new OutputStreamWrapper!(S, E)(stream);
}

unittest {
    import streams;
    // Test input stream wrapper.
    auto sIn1 = arrayInputStreamFor!ubyte([1, 2, 3, 4]);
    auto wrapIn1 = new InputStreamWrapper!(typeof(sIn1))(sIn1);
    ubyte[] buffer1 = new ubyte[4];
    assert(wrapIn1.read(buffer1) == 4);
    assert(buffer1 == [1, 2, 3, 4]);
    // Test using the function to make it easier.
    sIn1.reset();
    wrapIn1 = inputStreamWrapperFor(sIn1);
    assert(wrapIn1.read(buffer1[0 .. 2]) == 2);
    assert(buffer1[0 .. 2] == [1, 2]);

    // Test output stream wrapper.
    auto sOut1 = byteArrayOutputStream();
    auto wrapOut1 = new OutputStreamWrapper!(typeof(sOut1))(sOut1);
    assert(wrapOut1.write([1]) == 1);
    assert(sOut1.toArrayRaw() == [1]);
    wrapOut1 = outputStreamWrapperFor(sOut1);
    assert(wrapOut1.write([2, 3, 4]) == 3);
    assert(sOut1.toArrayRaw() == [1, 2, 3, 4]);
}
