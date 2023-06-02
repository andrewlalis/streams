/**
 * Concatenating streams that linearly combine reading and writing from
 * multiple resources.
 */
module streams.types.concat;

import streams.primitives;

/**
 * A concatenating input stream that reads from one stream until it returns
 * zero elements, then reads from the second stream.
 */
struct ConcatInputStream(E, S1, S2) if (isInputStream!(S1, E) && isInputStream!(S2, E)) {
    private S1 stream1;
    private bool stream1Empty = false;
    private S2 stream2;
    private bool stream2Empty = false;

    /**
     * Constructs a new concatenating stream from two input streams.
     * Params:
     *   stream1 = The first stream to read from.
     *   stream2 = The second stream to read from.
     */
    this(S1 stream1, S2 stream2) {
        this.stream1 = stream1;
        this.stream2 = stream2;
    }

    /** 
     * Reads from the streams that this one is concatenating, reading from the
     * first stream until it's empty, and then reading from the second stream.
     * Params:
     *   buffer = The buffer to read into.
     * Returns: The number of elements read, or an error.
     */
    StreamResult readFromStream(E[] buffer) {
        uint bufferIndex = 0;
        if (!this.stream1Empty) {
            StreamResult result1 = this.stream1.readFromStream(buffer);
            if (result1.hasError) return result1;
            if (result1.count == buffer.length) return result1;
            // Less than buffer.length elements were read.
            this.stream1Empty = true;
            bufferIndex = result1.count;
        }
        if (!this.stream2Empty) {
            const uint elementsToRead = cast(uint) buffer.length - bufferIndex;
            StreamResult result2 = this.stream2.readFromStream(buffer[bufferIndex .. $]);
            if (result2.hasError) return result2;
            if (result2.count == elementsToRead) return StreamResult(bufferIndex + result2.count);
            // Less than the required elements to fill the buffer were read.
            this.stream2Empty = true;
            return StreamResult(bufferIndex + result2.count);
        }
        // Both streams are empty.
        return StreamResult(0);
    }
}

/**
 * Function to obtain a concatenating input stream that reads from `stream1`,
 * and then `stream2`.
 * Params:
 *   stream1 = The first stream to read from.
 *   stream2 = The second stream to read from.
 * Returns: The concatenating input stream.
 */
ConcatInputStream!(StreamType!S1, S1, S2) concatInputStreamFor(S1, S2)(S1 stream1, S2 stream2) {
    return ConcatInputStream!(StreamType!S1, S1, S2)(stream1, stream2);
}

unittest {
    import streams.types.array;
    int[3] bufA = [1, 2, 3];
    int[3] bufB = [4, 5, 6];
    auto concatAandB = concatInputStreamFor(
        arrayInputStreamFor(bufA),
        arrayInputStreamFor(bufB)
    );
    int[2] buf;
    
    auto result = concatAandB.readFromStream(buf);
    assert(!result.hasError);
    assert(result.count == 2);
    assert(buf == [1, 2]);

    result = concatAandB.readFromStream(buf);
    assert(!result.hasError);
    assert(result.count == 2);
    assert(buf == [3, 4]);

    result = concatAandB.readFromStream(buf);
    assert(!result.hasError);
    assert(result.count == 2);
    assert(buf == [5, 6]);

    result = concatAandB.readFromStream(buf);
    assert(!result.hasError);
    assert(result.count == 0);
}
