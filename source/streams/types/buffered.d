/**
 * Defines buffered input and output streams that wrap around any other stream,
 * to allow it to buffer contents and flush only when full (or when a manual
 * `flush()` is called).
 */
module streams.types.buffered;

import streams.primitives : StreamType, isInputStream, isSomeInputStream, isOutputStream, isSomeOutputStream;

/** 
 * The default size for buffered input and output streams.
 */
const uint DEFAULT_BUFFER_SIZE = 4096;

/** 
 * A buffered wrapper around another input stream, that buffers data that's
 * been read into an internal buffer, so that calls to `readToStream` don't all
 * necessitate reading from the underlying resource.
 */
struct BufferedInputStream(S, E = StreamType!S, uint BufferSize = DEFAULT_BUFFER_SIZE) if (isInputStream!(S, E)) {
    private S* stream;
    private E[BufferSize] internalBuffer;
    private uint nextIndex = BufferSize;
    private uint elementsInBuffer = 0;
    private bool streamEnded = false;

    /** 
     * Constructs a buffered input stream to buffer reads from the given stream.
     * Params:
     *   stream = The stream to read from.
     */
    this(ref S stream) {
        this.stream = &stream;
    }

    /** 
     * Reads elements into the given buffer, first pulling from this buffered
     * stream's internal buffer, and then reading from the underlying stream.
     * Params:
     *   buffer = The buffer to read items to.
     * Returns: The number of elements read, or -1 in case of error.
     */
    int readFromStream(E[] buffer) {
        int elementsRead = 0;
        while (elementsRead < buffer.length) {
            // First copy as much as we can from our internal buffer to the outbuffer.
            E[] writableSlice = buffer[elementsRead .. $];
            uint elementsFromInternal = this.readFromInternalBuffer(writableSlice);
            elementsRead += elementsFromInternal;

            // Then, if necessary, refresh the internal buffer.
            if (elementsRead < buffer.length && !this.streamEnded) {
                int readResult = this.refreshInternalBuffer();
                if (readResult < 0) return readResult;
            } else if (this.streamEnded) {
                break; // Quit reading if the stream has ended.
            }
        }
        return elementsRead;
    }

    /** 
     * Reads as many elements as possible from the internal buffer, writing to
     * the given buffer parameter.
     * Params:
     *   buffer = The buffer to write to.
     * Returns: The number of elements that were read.
     */
    private uint readFromInternalBuffer(E[] buffer) {
        if (this.elementsInBuffer == 0) return 0;
        const uint elementsAvailable = this.elementsInBuffer - this.nextIndex;
        if (elementsAvailable == 0) return 0;
        const uint elementsToCopy = elementsAvailable < buffer.length ? elementsAvailable : cast(uint) buffer.length;
        buffer[0 .. elementsToCopy] = this.internalBuffer[this.nextIndex .. this.nextIndex + elementsToCopy];
        this.nextIndex += elementsToCopy;
        return elementsToCopy;
    }

    /** 
     * Refreshes the internal buffer by reading from the underlying stream.
     * Returns: The result of the stream read operation.
     */
    private int refreshInternalBuffer() {
        if (this.streamEnded) return 0;
        int result = this.stream.readFromStream(this.internalBuffer);
        if (result < 0) return result; // Exit right away in case of error.
        this.nextIndex = 0;
        if (result < BufferSize) {
            this.streamEnded = true;
        }
        this.elementsInBuffer = result;
        return result;
    }
}

/** 
 * Creates and returns a buffered input stream that's wrapped around the given
 * input stream.
 * Params:
 *   stream = The stream to wrap in a buffered input stream.
 * Returns: The buffered input stream.
 */
BufferedInputStream!S bufferedInputStreamFor(S, uint BufferSize = DEFAULT_BUFFER_SIZE)(
    ref S stream
) if (isSomeInputStream!S) {
    return BufferedInputStream!(S, StreamType!S, BufferSize)(stream);
}

unittest {
    import streams.types.array : arrayInputStreamFor;

    // Test basic operations.
    int[4] sInData = [1, 2, 3, 4];
    auto sIn1 = arrayInputStreamFor!int(sInData);
    auto bufIn1 = bufferedInputStreamFor(sIn1);
    int[1] buf1;
    int readResult1 = bufIn1.readFromStream(buf1);
    assert(readResult1 == 1);
    assert(buf1 == [1]);
    int[4] buf2;
    int readResult2 = bufIn1.readFromStream(buf2);
    assert(readResult2 == 3);

    // Check that a read error propagates.
    import streams.primitives : ErrorInputStream;
    auto sIn3 = ErrorInputStream!int();
    auto bufIn3 = BufferedInputStream!(typeof(sIn3), int)(sIn3);
    int[64] buf3;
    assert(bufIn3.readFromStream(buf3) == -1);

    // Check that a closed input stream results in reads of 0.
    import streams.primitives : NoOpInputStream;
    auto sIn4 = NoOpInputStream!bool();
    auto bufIn4 = BufferedInputStream!(typeof(sIn4))(sIn4);
    bool[3] buf4;
    assert(bufIn4.readFromStream(buf4) == 0);
}

/** 
 * A buffered wrapper around another output stream, that buffers writes up to
 * `BufferSize` elements before flushing the buffer to the underlying stream.
 */
struct BufferedOutputStream(S, E = StreamType!E, uint BufferSize = DEFAULT_BUFFER_SIZE) if (isOutputStream!(S, E)) {
    private S* stream;
    private E[BufferSize] internalBuffer;
    private uint nextIndex = 0;

    /** 
     * Constructs a buffered output stream to buffer writes to the given stream.
     * Params:
     *   stream = The stream to write to.
     */
    this(ref S stream) {
        this.stream = &stream;
    }

    /** 
     * Writes the given items this stream's internal buffer, and flushes if we
     * reach the buffer's capacity.
     * Params:
     *   buffer = The elements to write.
     * Returns: The number of elements that were written, or -1 in case of error.
     */
    int writeToStream(E[] buffer) {
        int elementsWritten = 0;
        uint bufferIndex = 0;
        while (bufferIndex < buffer.length) {
            // Determine how many elements we can copy to our buffer at once.
            const uint remainingElements = cast(uint) buffer.length - bufferIndex;
            const uint remainingCapacity = BufferSize - nextIndex;
            const uint elementsToWrite = remainingElements > remainingCapacity ? remainingCapacity : remainingElements;

            // Do the copy operation.
            const newInternalBufferIndex = this.nextIndex + elementsToWrite;
            const newBufferIndex = bufferIndex + elementsToWrite;
            this.internalBuffer[this.nextIndex .. newInternalBufferIndex] = buffer[bufferIndex .. newBufferIndex];

            // Update our state, and flush if we've filled up our buffer.
            this.nextIndex = newInternalBufferIndex;
            bufferIndex = newBufferIndex;
            elementsWritten += elementsToWrite;

            if (this.nextIndex == BufferSize) {
                int result = this.internalFlush();
                if (result == -1) return -1; // If we detect an error, quit immediately.
            }
        }
        return elementsWritten;
    }

    private int internalFlush() {
        int result = this.stream.writeToStream(this.internalBuffer[0 .. this.nextIndex]);
        if (result != -1) {
            this.nextIndex = 0;
        }
        return result;
    }

    /** 
     * Manually invokes a flush to the underlying stream.
     */
    void flushStream() {
        this.internalFlush();
    }
}

unittest {
    import streams.primitives : isFlushableStream;
    import streams.types.array : byteArrayOutputStream;

    auto sOut1 = byteArrayOutputStream();
    auto bufOut1 = BufferedOutputStream!(typeof(sOut1), ubyte, 4)(sOut1);

    assert(isOutputStream!(typeof(bufOut1), ubyte));
    assert(isFlushableStream!(typeof(bufOut1)));

    ubyte[5] data = [1, 2, 3, 4, 5];
    assert(bufOut1.writeToStream(data[0 .. 1]) == 1);
    assert(sOut1.toArrayRaw().length == 0);
    assert(bufOut1.writeToStream(data[1 .. 2]) == 1);
    assert(sOut1.toArrayRaw().length == 0);
    assert(bufOut1.writeToStream(data[2 .. 4]) == 2);
    assert(sOut1.toArrayRaw() == [1, 2, 3, 4]);
    assert(bufOut1.writeToStream(data[4 .. 5]) == 1);
    assert(sOut1.toArrayRaw().length == 4);
    bufOut1.flushStream();
    assert(sOut1.toArrayRaw() == [1, 2, 3, 4, 5]);
}
