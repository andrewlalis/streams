/**
 * Defines buffered input and output streams that wrap around any other stream,
 * to allow it to buffer contents and flush only when full (or when a manual
 * `flush()` is called).
 */
module streams.types.buffered;

import streams.primitives;
import std.typecons;

const uint DEFAULT_BUFFER_SIZE = 4096;

struct BufferedInputStream(S, E = StreamType!S) if (isInputStream!(S, E)) {
    private S* stream;
    private const Nullable!E delimiter = Nullable!E.init;

    this(ref S stream) {
        this.stream = &stream;
    }

    int read(E[] buffer) {
        uint bufferIndex = 0;
        while (bufferIndex < buffer.length) {
            int elementsRead = this.stream.read(buffer[bufferIndex .. $]);
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
    import streams;
    import core.thread;

    auto sIn1 = arrayInputStreamFor!int([1, 2, 3, 4]);
    auto bufIn1 = BufferedInputStream!(typeof(sIn1), int)(sIn1);
    int[1] buf1;
    assert(bufIn1.read(buf1[]) == 1);
    assert(buf1 == [1]);
    int[4] buf2;
    assert(bufIn1.read(buf2[]) == 3);

}

struct BufferedOutputStream(S, E = StreamType!E, uint BufferSize = DEFAULT_BUFFER_SIZE) if (isOutputStream!(S, E)) {
    private S* stream;
    private E[BufferSize] internalBuffer;
    private uint nextIndex = 0;

    this(ref S stream) {
        this.stream = &stream;
    }

    int write(E[] buffer) {
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
        int result = this.stream.write(this.internalBuffer[0 .. this.nextIndex]);
        if (result != -1) {
            this.nextIndex = 0;
        }
        return result;
    }

    void flush() {
        this.internalFlush();
    }
}

unittest {
    import streams;
    auto sOut1 = byteArrayOutputStream();
    auto bufOut1 = BufferedOutputStream!(typeof(sOut1), ubyte, 4)(sOut1);

    assert(isOutputStream!(typeof(bufOut1), ubyte));
    assert(isFlushableStream!(typeof(bufOut1)));

    assert(bufOut1.write([1]) == 1);
    assert(sOut1.toArrayRaw().length == 0);
    assert(bufOut1.write([2]) == 1);
    assert(sOut1.toArrayRaw().length == 0);
    assert(bufOut1.write([3, 4]) == 2);
    assert(sOut1.toArrayRaw() == [1, 2, 3, 4]);
    assert(bufOut1.write([5]) == 1);
    assert(sOut1.toArrayRaw().length == 4);
    bufOut1.flush();
    assert(sOut1.toArrayRaw() == [1, 2, 3, 4, 5]);
}
