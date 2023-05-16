/**
 * Defines buffered input and output streams that wrap around any other stream,
 * to allow it to buffer contents and flush only when full (or when a manual
 * `flush()` is called).
 */
module streams.types.buffered;

import streams.primitives : StreamType, isInputStream, isOutputStream;

const uint DEFAULT_BUFFER_SIZE = 4096;

/** 
 * A buffered wrapper around another input stream, that buffers reads according
 * to the size of buffer provided to its `readFromStream` method.
 */
struct BufferedInputStream(S, E = StreamType!S) if (isInputStream!(S, E)) {
    private S* stream;

    /** 
     * Constructs a buffered input stream to buffer reads from the given stream.
     * Params:
     *   stream = The stream to read from.
     */
    this(ref S stream) {
        this.stream = &stream;
    }

    /** 
     * Reads `buffer.length` items from the stream, and returning only once
     * exactly that many items have been read, or an error occurs.
     * Params:
     *   buffer = The buffer to read items to.
     * Returns: `buffer.length` on success, or `-1` on error.
     */
    int readFromStream(E[] buffer) {
        uint bufferIndex = 0;
        while (bufferIndex < buffer.length) {
            int elementsRead = this.stream.readFromStream(buffer[bufferIndex .. $]);
            if (elementsRead == 0) {
                return bufferIndex; // Return the total number of elements we read so far.
            } else if (elementsRead == -1) {
                return -1;
            }
            bufferIndex += elementsRead;
        }
        return cast(uint) buffer.length;
    }
}

unittest {
    import streams.types.array : arrayInputStreamFor;

    int[4] sInData = [1, 2, 3, 4];
    auto sIn1 = arrayInputStreamFor!int(sInData);
    auto bufIn1 = BufferedInputStream!(typeof(sIn1), int)(sIn1);
    int[1] buf1;
    assert(bufIn1.readFromStream(buf1[]) == 1);
    assert(buf1 == [1]);
    int[4] buf2;
    assert(bufIn1.readFromStream(buf2[]) == 3);

    // Check that a read error propagates.
    import streams.primitives : ErrorInputStream;
    auto sIn3 = ErrorInputStream!int();
    auto bufIn3 = BufferedInputStream!(typeof(sIn3), int)(sIn3);
    int[64] buf3;
    assert(bufIn3.readFromStream(buf3) == -1);
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
