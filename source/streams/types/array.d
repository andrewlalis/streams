/** 
 * A collection of array-backed streams for in-memory reading and writing.
 */
module streams.types.array;

import streams.primitives : StreamResult, StreamError, OptionalStreamError;

/** 
 * An input stream that reads from an array of items.
 */
struct ArrayInputStream(E) {
    private E[] array;
    private uint currentIndex = 0;

    /** 
     * Reads items from this input stream's array into the given buffer,
     * where successive `read` calls will read sequentially from the array,
     * so that, for example, with an array `[1, 2, 3, 4]`, reading with a
     * buffer size of 2 will first read `[1, 2]`, and then `[3, 4]`.
     * Params:
     *   buffer = The buffer read array elements into.
     * Returns: The number of elements that were read.
     */
    StreamResult readFromStream(E[] buffer) {
        if (this.currentIndex >= this.array.length) return StreamResult(0);
        uint lengthToRead = cast(uint) this.array.length - this.currentIndex;
        if (lengthToRead > buffer.length) {
            lengthToRead = cast(uint) buffer.length;
        }
        buffer[0 .. lengthToRead] = this.array[this.currentIndex .. this.currentIndex + lengthToRead];
        this.currentIndex += lengthToRead;
        return StreamResult(lengthToRead);
    }

    /** 
     * Resets this input stream's record of the next index to read from, so
     * that the next call to `read` will read from the start of the array.
     */
    OptionalStreamError reset() {
        this.currentIndex = 0;
        return OptionalStreamError.init;
    }
}

unittest {
    import streams.primitives : isSomeInputStream, isInputStream;

    assert(isSomeInputStream!(ArrayInputStream!int));
    assert(isInputStream!(ArrayInputStream!ubyte, ubyte));

    int[5] data = [1, 2, 3, 4, 5];
    auto s1 = ArrayInputStream!int(data);
    int[2] buffer;
    assert(s1.readFromStream(buffer) == StreamResult(2));
    assert(buffer == [1, 2]);
    assert(s1.readFromStream(buffer) == StreamResult(2));
    assert(buffer == [3, 4]);
    assert(s1.readFromStream(buffer) == StreamResult(1));
    assert(buffer == [5, 4]);
    assert(s1.readFromStream(buffer) == StreamResult(0));

    s1.reset();
    assert(s1.readFromStream(buffer) == StreamResult(2));
    assert(buffer == [1, 2]);
    // Test that the stream works for a single buffer.
    int[1] singleBuffer;
    assert(s1.readFromStream(singleBuffer) == StreamResult(1));
    assert(singleBuffer[0] == 3);
    assert(s1.readFromStream(singleBuffer) == StreamResult(1));
    assert(singleBuffer[0] == 4);
    s1.readFromStream(singleBuffer); // Skip the last element.
    assert(s1.readFromStream(singleBuffer) == StreamResult(0));

    // Test reading to a buffer that's larger than the stream's internal buffer.
    ubyte[4] data3 = [5, 4, 3, 2];
    ubyte[10] buffer3;
    auto s3 = ArrayInputStream!ubyte(data3);
    assert(s3.readFromStream(buffer3) == StreamResult(4));
    assert(buffer3[0 .. 4] == data3);
    assert(s3.readFromStream(buffer3) == StreamResult(0));

}

/** 
 * Creates and returns an array input stream wrapped around the given array
 * of elements.
 * Params:
 *   array = The array to stream.
 * Returns: The array input stream.
 */
ArrayInputStream!E arrayInputStreamFor(E)(E[] array) {
    return ArrayInputStream!E(array);
}

const uint DEFAULT_INITIAL_CAPACITY = 64;

/** 
 * An output stream that writes to an internal array. The resulting array can
 * be obtained with `toArray()`. It is BetterC compatible, using manual memory
 * management.
 *
 * When constructed, an initial block of memory is allocated, and then any new
 * memory will be allocated according to the output stream's allocation
 * strategy. If the `None` strategy is used, attempts to write more elements
 * than the array contains will throw an unrecoverable Error.
 */
struct ArrayOutputStream(E) {
    import streams.utils : AppendableBuffer, BufferAllocationStrategy;

    private AppendableBuffer!E buffer = AppendableBuffer!E(DEFAULT_INITIAL_CAPACITY, BufferAllocationStrategy.Doubling);

    /** 
     * Writes data to this output stream's internal array.
     * Params:
     *   buffer = The elements to write to the stream.
     * Returns: The number of elements that were written. Barring memory
     * issues, this will always equal the buffer's length.
     */
    StreamResult writeToStream(E[] buffer) {
        this.buffer.appendItems(buffer);
        return StreamResult(cast(uint) buffer.length);
    }

    version (D_BetterC) {} else {
        /** 
         * Gets the internal array to which elements have been appended. This
         * method is not compatible with BetterC mode; use `toArrayRaw` for that.
         * Returns: The internal array.
         */
        E[] toArray() {
            E[] array = this.toArrayRaw();
            E[] dynArray = new E[array.length];
            dynArray[0 .. $] = array[0 .. $];
            return dynArray;
        }
    }

    /** 
     * Gets a slice representing the underlying array to which elements have
     * been appended. Take caution, as this memory segment may be freed if this
     * stream is deconstructed or written to again.
     * Returns: A slice representing the array of elements that have been added
     * to this stream.
     */
    E[] toArrayRaw() {
        return this.buffer.toArray();
    }

    /** 
     * Resets the internal array, such that `toArray()` returns an empty
     * array.
     */
    void reset() {
        this.buffer.reset();
    }
}

/** 
 * Creates and returns an array output stream for elements of the given type,
 * using a default initial capacity of `ArrayOutputStream.DEFAULT_INITIAL_CAPACITY`
 * and default allocation strategy of `AllocationStrategy.Doubling`.
 * Returns: The array output stream.
 */
ArrayOutputStream!E arrayOutputStreamFor(E)() {
    return ArrayOutputStream!E();
}

/** 
 * Creates and returns a byte array output stream.
 * Returns: The byte array output stream.
 */
ArrayOutputStream!ubyte byteArrayOutputStream() {
    return arrayOutputStreamFor!ubyte;
}

unittest {
    import streams.primitives : isSomeOutputStream;

    assert(isSomeOutputStream!(ArrayOutputStream!bool));

    auto s1 = arrayOutputStreamFor!float;
    float[3] buffer = [0.5, 1, 1.5];
    assert(s1.writeToStream(buffer) == StreamResult(3));
    buffer = [2, 2.5, 3];
    assert(s1.writeToStream(buffer) == StreamResult(3));
    assert(s1.toArrayRaw() == [0.5, 1, 1.5, 2, 2.5, 3]);
    assert(s1.toArrayRaw() == [0.5, 1, 1.5, 2, 2.5, 3]);

    auto s2 = byteArrayOutputStream();
    ubyte[3] buffer1 = [1, 2, 3];
    s2.writeToStream(buffer1);
    ubyte[] data = s2.toArrayRaw();
    assert(data == [1, 2, 3]);

    s2.reset();
    assert(s2.toArrayRaw().length == 0);
    s2.writeToStream(buffer1);
    assert(s2.toArrayRaw() == [1, 2, 3]);

    version (D_BetterC) {} else {
        // Test the dynamic toArray method.
        assert(s2.toArray() == [1, 2, 3]);
    }
}
