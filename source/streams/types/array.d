/** 
 * A collection of array-backed streams for in-memory reading and writing.
 */
module streams.types.array;

/** 
 * An input stream that reads from an array of items.
 */
struct ArrayInputStream(DataType) {
    private DataType[] array;
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
    int read(DataType[] buffer) {
        if (this.currentIndex >= this.array.length) return 0;
        uint bufferLength = cast(uint) buffer.length;
        uint lengthRemaining = cast(uint) this.array.length - this.currentIndex;
        uint lengthToRead = lengthRemaining < bufferLength ? lengthRemaining : bufferLength;
        buffer[0 .. lengthToRead] = this.array[this.currentIndex .. this.currentIndex + lengthToRead];
        this.currentIndex += lengthToRead;
        return lengthToRead;
    }

    /** 
     * Resets this input stream's record of the next index to read from, so
     * that the next call to `read` will read from the start of the array.
     */
    void reset() {
        this.currentIndex = 0;
    }
}

unittest {
    import streams.primitives;

    assert(isSomeInputStream!(ArrayInputStream!int));
    assert(isInputStream!(ArrayInputStream!ubyte, ubyte));

    auto s1 = ArrayInputStream!int([1, 2, 3, 4, 5]);
    int[] buffer = new int[2];
    assert(s1.read(buffer) == 2);
    assert(buffer == [1, 2]);
    assert(s1.read(buffer) == 2);
    assert(buffer == [3, 4]);
    assert(s1.read(buffer) == 1);
    assert(buffer == [5, 4]);

    s1.reset();
    assert(s1.read(buffer) == 2);
    assert(buffer == [1, 2]);
}

/** 
 * Creates and returns an array input stream wrapped around the given array
 * of elements.
 * Params:
 *   array = The array to stream.
 * Returns: The array input stream.
 */
ArrayInputStream!T arrayInputStreamFor(T)(T[] array) {
    return ArrayInputStream!T(array);
}

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
struct ArrayOutputStream(DataType) {
    import core.stdc.stdlib : malloc, realloc, free;

    static enum AllocationStrategy { Linear, Doubling, None }
    static const uint DEFAULT_INITIAL_CAPACITY = 64;
    
    private DataType* arrayPtr;
    const AllocationStrategy allocationStrategy;
    const uint initialArrayCapacity;
    private uint arrayCapacity;
    private uint nextArrayIndex = 0;

    @disable this();

    /** 
     * Constructs this output stream with a specified initial capacity and
     * allocation strategy. Consider using `arrayOutputStreamFor!T()` to use
     * sensible default values instead of this constructor.
     * Params:
     *   initialCapacity = The initial capacity of the output stream's array.
     *   allocationStrategy = The strategy for how to allocate memory if the
     *                        stream's array reaches capacity.
     */
    this(uint initialCapacity, AllocationStrategy allocationStrategy) {
        this.arrayPtr = cast(DataType*) malloc(initialCapacity * DataType.sizeof);
        if (this.arrayPtr is null) {
            throw new Error("Failed to allocate memory for array."); // cov-ignore
        }
        this.allocationStrategy = allocationStrategy;
        this.initialArrayCapacity = initialCapacity;
        this.arrayCapacity = initialCapacity;
        this.nextArrayIndex = 0;
    }

    ~this() {
        free(this.arrayPtr);
    }

    /** 
     * Writes data to this output stream's internal array.
     * Params:
     *   buffer = The elements to write to the stream.
     * Returns: The number of elements that were written. Barring memory
     * issues, this will always equal the buffer's length.
     */
    int write(DataType[] buffer) {
        uint len = cast(uint) buffer.length;
        this.ensureCapacityFor(len);
        DataType[] array = this.arrayPtr[0 .. this.arrayCapacity];
        array[this.nextArrayIndex .. this.nextArrayIndex + len] = buffer[0 .. $];
        this.nextArrayIndex += len;
        return len;
    }

    private void ensureCapacityFor(uint count) {
        while ((this.arrayCapacity - this.nextArrayIndex) < count) {
            uint newArrayCapacity;
            final switch (this.allocationStrategy) {
                case AllocationStrategy.Linear:
                    newArrayCapacity = this.arrayCapacity + this.initialArrayCapacity;
                    break;
                case AllocationStrategy.Doubling:
                    newArrayCapacity = this.arrayCapacity * 2;
                    break;
                case AllocationStrategy.None: // cov-ignore
                    throw new Error("Not enough capacity to add more items to ArrayOutputStream."); // cov-ignore
            }
            DataType* newPtr = cast(DataType*) realloc(this.arrayPtr, newArrayCapacity * DataType.sizeof);
            if (newPtr is null) {
                free(this.arrayPtr); // cov-ignore
                throw new Error("Could not reallocate memory."); // cov-ignore
            }
            this.arrayPtr = newPtr;
            this.arrayCapacity = newArrayCapacity;
        }
    }

    version (D_BetterC) {} else {
        /** 
         * Gets the internal array to which elements have been appended. This
         * method is not compatible with BetterC mode; use `toArrayRaw` for that.
         * Returns: The internal array.
         */
        DataType[] toArray() const {
            DataType[] array = new DataType[this.nextArrayIndex];
            array[0 .. $] = this.arrayPtr[0 .. this.nextArrayIndex];
            return array;
        }
    }

    uint capacity() const {
        return this.arrayCapacity;
    }

    /** 
     * Gets a slice representing the underlying array to which elements have
     * been appended. Take caution, as this memory segment may be freed if this
     * stream is deconstructed or written to again.
     * Returns: A slice representing the array of elements that have been added
     * to this stream.
     */
    DataType[] toArrayRaw() {
        return this.arrayPtr[0 .. this.nextArrayIndex];
    }

    /** 
     * Resets the internal array, such that `toArray()` returns an empty
     * array.
     */
    void reset() {
        if (this.arrayPtr !is null) {
            free(this.arrayPtr);
        }
        this.arrayPtr = cast(DataType*) malloc(this.initialArrayCapacity * DataType.sizeof);
        if (this.arrayPtr is null) {
            throw new Error("Failed to allocate memory for array."); // cov-ignore
        }
        this.arrayCapacity = this.initialArrayCapacity;
        this.nextArrayIndex = 0;
    }
}

/** 
 * Creates and returns an array output stream for elements of the given type,
 * using a default initial capacity of `ArrayOutputStream.DEFAULT_INITIAL_CAPACITY`
 * and default allocation strategy of `AllocationStrategy.Doubling`.
 * Returns: The array output stream.
 */
ArrayOutputStream!T arrayOutputStreamFor(T)() {
    return ArrayOutputStream!T(
        ArrayOutputStream!T.DEFAULT_INITIAL_CAPACITY,
        ArrayOutputStream!T.AllocationStrategy.Doubling
    );
}

/** 
 * Creates and returns a byte array output stream.
 * Returns: The byte array output stream.
 */
ArrayOutputStream!ubyte byteArrayOutputStream() {
    return arrayOutputStreamFor!ubyte;
}

unittest {
    import streams.primitives;
    import std.stdio;

    assert(isSomeOutputStream!(ArrayOutputStream!bool));

    auto s1 = arrayOutputStreamFor!float;
    float[] buffer = [0.5, 1, 1.5];
    assert(s1.write(buffer) == 3);
    buffer = [2, 2.5, 3];
    assert(s1.write(buffer) == 3);
    assert(s1.toArray() == [0.5, 1, 1.5, 2, 2.5, 3]);
    assert(s1.toArrayRaw() == [0.5, 1, 1.5, 2, 2.5, 3]);

    auto s2 = byteArrayOutputStream();
    ubyte[] buffer1 = [1, 2, 3];
    s2.write(buffer1);
    ubyte[] data = s2.toArray();
    assert(data == [1, 2, 3]);

    s2.reset();
    assert(s2.toArray().length == 0);
    s2.write(buffer1);
    assert(s2.toArray() == [1, 2, 3]);

    // Test that capacity increasing works for various allocation strategies.
    auto s3 = ArrayOutputStream!int(2, ArrayOutputStream!int.AllocationStrategy.Linear);
    assert(s3.capacity == 2);
    assert(s3.allocationStrategy == ArrayOutputStream!int.AllocationStrategy.Linear);
    assert(s3.write([1, 2]) == 2);
    assert(s3.capacity == 2);
    assert(s3.write([3]) == 1);
    assert(s3.capacity == 4); // Check that the capacity grew linearly by a multiple of the original capacity.
    assert(s3.write([4, 5, 6]) == 3);
    assert(s3.capacity == 6);

    auto s4 = ArrayOutputStream!int(2, ArrayOutputStream!int.AllocationStrategy.Doubling);
    assert(s4.write([1, 2]) == 2);
    assert(s4.capacity == 2);
    assert(s4.write([3, 4]) == 2);
    assert(s4.capacity == 4);
    assert(s4.write([5, 6]) == 2);
    assert(s4.capacity == 8);
}
