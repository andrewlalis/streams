/** 
 * Collection of utilities for stream components.
 */
module streams.utils;

/** 
 * A simple nullable type, where a boolean flag indicates whether a value is
 * present.
 */
struct Optional(T) {
    const bool present = false;
    const T value = T.init;

    this(T value) {
        this.present = true;
        this.value = value;
    }

    bool notPresent() const {
        return !this.present;
    }
}

unittest {
    Optional!int op1;
    assert(op1.present == false);
    assert(op1.value == int.init);
    Optional!bool op2 = Optional!bool(true);
    assert(op2.present);
    assert(op2.value == true);
}

/** 
 * A type that contains either an element of A, or an element of B, but not both.
 */
struct Either(A, B) if (!is(A == B)) {
    const Optional!A first;
    const Optional!B second;

    this(A value) {
        this.first = Optional!A(value);
        this.second = Optional!B.init;
    }

    this(B value) {
        this.second = Optional!B(value);
        this.first = Optional!A.init;
    }

    invariant {
        assert((first.present || second.present) && !(first.present && second.present));
    }

    T map(T)(T delegate(A) dgA, T delegate(B) dgB) {
        if (first.present) return dgA(first.value);
        return dgB(second.value);
    }
}

unittest {
    auto e1 = Either!(int, bool)(5);
    assert(e1.first.present);
    assert(e1.second.notPresent);
}

/** 
 * A strategy for how to grow a buffer as items are added, used by the AppendableBuffer.
 */
enum BufferAllocationStrategy { Linear, Doubling, None }

/** 
 * A betterC-compatible array buffer that grows as needed to accommodate new
 * elements.
 */
struct AppendableBuffer(T) {
    import core.stdc.stdlib : malloc, realloc, free;

    private T* ptr;
    private const BufferAllocationStrategy allocationStrategy;
    private const uint initialCapacity;
    private uint capacity;
    private uint nextIndex;

    @disable this();

    /** 
     * Constructs the buffer using the given initial capacity and allocation
     * strategy. No memory is allocated yet.
     * Params:
     *   initialCapacity = The capacity of the buffer.
     *   allocationStrategy = The strategy for memory allocation.
     */
    this(uint initialCapacity, BufferAllocationStrategy allocationStrategy) {
        this.initialCapacity = initialCapacity;
        this.allocationStrategy = allocationStrategy;
    }

    ~this() {
        if (this.ptr !is null) {
            free(this.ptr);
        }
    }

    /** 
     * Appends items to the buffer, expanding the buffer if needed.
     * Params:
     *   items = The items to add.
     */
    void appendItems(T[] items) {
        if (this.ptr is null) reset();

        uint len = cast(uint) items.length;
        this.ensureCapacityFor(len);
        T[] array = this.ptr[0 .. this.capacity];
        array[this.nextIndex .. this.nextIndex + len] = items[0 .. $];
        this.nextIndex += len;
    }

    /** 
     * Gets a slice representing the buffer's contents.
     * Returns: The buffer's contents.
     */
    T[] toArray() {
        return this.ptr[0 .. this.nextIndex];
    }

    /** 
     * Gets the length of the buffer, or the total number of items in it.
     * Returns: The buffer's length.
     */
    uint length() const {
        return this.nextIndex;
    }

    /** 
     * Resets the buffer.
     */
    void reset() {
        if (this.ptr !is null) {
            free(this.ptr);
        }
        this.ptr = cast(T*) malloc(this.initialCapacity * T.sizeof);
        if (this.ptr is null) {
            assert(false, "Failed to allocate appendable buffer.");
        }
        this.capacity = this.initialCapacity;
        this.nextIndex = 0;
    }

    private void ensureCapacityFor(uint count) {
        while ((this.capacity - this.nextIndex) < count) {
            uint newCapacity;
            final switch (this.allocationStrategy) {
                case BufferAllocationStrategy.Linear:
                    newCapacity = this.capacity + this.initialCapacity;
                    break;
                case BufferAllocationStrategy.Doubling:
                    newCapacity = this.capacity * 2;
                    break;
                case BufferAllocationStrategy.None:
                    assert(false, "Cannot allocate more space to appendable buffer using None strategy.");
            }
            T* newPtr = cast(T*) realloc(this.ptr, newCapacity * T.sizeof);
            if (newPtr is null) {
                free(this.ptr);
                assert(false, "Could not reallocate appendable buffer.");
            }
            this.ptr = newPtr;
            this.capacity = newCapacity;
        }
    }
}

