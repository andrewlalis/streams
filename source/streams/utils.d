/** 
 * Collection of utilities for stream components.
 */
module streams.utils;

/** 
 * A simple nullable type, where a boolean flag indicates whether a value is
 * present.
 */
struct Optional(T) {
    /** 
     * Whether the value is present.
     */
    bool present = false;

    /** 
     * The value that's present, if any.
     */
    T value = T.init;

    /** 
     * Constructs an optional with a given value.
     * Params:
     *   value = The value to use.
     */
    this(T value) {
        this.present = true;
        this.value = value;
    }

    /** 
     * Determines if a value is not present.
     * Returns: True if the value is not present.
     */
    bool notPresent() const {
        return !this.present;
    }
}

unittest {
    Optional!int op1;
    assert(op1.present == false);
    assert(op1.value == int.init);
    assert(op1.notPresent);
    Optional!bool op2 = Optional!bool(true);
    assert(op2.present);
    assert(op2.value == true);
}

/** 
 * A type that contains either an element of A, or an element of B, but not both.
 * You can access the given names directly, so for example:
 *
 * `auto s = Either!(bool, "first", float, "second")(true);`
 *
 * will allow you to call `s.first`, `s.second`, `s.hasFirst`, and `s.hasSecond`.
 */
struct Either(A, string NameA, B, string NameB) if (!is(A == B)) {
    alias firstType = A;
    alias secondType = B;

    private enum checkA = "has" ~ (NameA[0] - ('a' - 'A')) ~ NameA[1 .. $];
    private enum checkB = "has" ~ (NameB[0] - ('a' - 'A')) ~ NameB[1 .. $];

    union U {
        A a;
        B b;
        this(A a) {
            this.a = a;
        }
        this(B b) {
            this.b = b;
        }
    }
    private bool hasA = true;
    private U u;

    this(A value) {
        this.u = U(value);
        this.hasA = true;
    }

    this(B value) {
        this.u = U(value);
        this.hasA = false;
    }

    A opDispatch(string member)() if (member == NameA) {
        return this.u.a;
    }

    B opDispatch(string member)() if (member == NameB) {
        return this.u.b;
    }

    bool opDispatch(string member)() const if (member == checkA) {
        return this.hasA;
    }

    bool opDispatch(string member)() const if (member == checkB) {
        return !this.hasA;
    }

    bool has(string member)() const if (member == NameA || member == NameB) {
        static if (member == NameA) {
            return this.hasA;
        } else {
            return !this.hasA;
        }
    }

    T map(T)(T delegate(A) dgA, T delegate(B) dgB) const {
        if (this.hasA) return dgA(this.u.a);
        return dgB(this.u.b);
    }
}

unittest {
    auto e1 = Either!(int, "first", bool, "second")(5);
    assert(e1.has!"first");
    assert(e1.hasFirst);
    assert(!e1.has!"second");
    assert(!e1.hasSecond);
    assert(e1.first == 5);

    auto e2 = Either!(float, "first", ubyte, "second")(3u);
    assert(!e2.has!"first");
    assert(!e2.hasFirst);
    assert(e2.has!"second");
    assert(e2.hasSecond);
    assert(e2.second == 3);
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
    // import std.stdio;
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
        // writeln("Freeing appendable buffer");
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
        // writefln!"Appending %d items"(items.length);
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
     * Gets a copy of this buffer's contents in a new allocated array. You must
     * free this array yourself.
     * Returns: The array copy.
     */
    T[] toArrayCopy() {
        T* copyPtr = cast(T*) malloc(this.length() * T.sizeof);
        if (copyPtr is null) assert(false, "Could not allocate memory for arrayCopy.");
        T[] copy = copyPtr[0 .. this.length()];
        copy[0 .. $] = this.toArray()[0 .. $];
        return copy;
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
        // writeln("Resetting appendable buffer");
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
            // writefln!"Ensuring capacity for %d new items"(count);
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
            // writeln("Reallocating pointer");
            T* newPtr = cast(T*) realloc(this.ptr, newCapacity * T.sizeof);
            if (newPtr is null) {
                free(this.ptr); // Can't test this without mocking realloc... cov-ignore
                assert(false, "Could not reallocate appendable buffer.");
            }
            this.ptr = newPtr;
            this.capacity = newCapacity;
            // writefln!"New capacity: %d"(this.capacity);
        }
    }
}

unittest {
    auto ab1 = AppendableBuffer!ubyte(4, BufferAllocationStrategy.Doubling);
    assert(ab1.length() == 0);
    assert(ab1.toArray() == []);
    ubyte[3] buf = [1, 2, 3];
    ab1.appendItems(buf);
    assert(ab1.length() == 3);
    assert(ab1.toArray() == [1, 2, 3]);

    buf = [4, 5, 6];
    ab1.appendItems(buf);
    assert(ab1.toArray() == [1, 2, 3, 4, 5, 6]);
    ubyte[] copy = ab1.toArrayCopy();
    assert(copy.length == 6);
    import core.stdc.stdlib : free;
    free(copy.ptr);

    // Test a linear buffer allocation strategy.
    auto ab2 = AppendableBuffer!int(4, BufferAllocationStrategy.Linear);
    assert(ab2.length() == 0);
    for (uint i = 0; i < 10; i++) {
        int[1] buf2 = [i];
        ab2.appendItems(buf2);
    }
    assert(ab2.length() == 10);
    assert(ab2.toArray() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
}

/** 
 * Reverses the elements of the given array in-place.
 * Params:
 *   array = The array to reverse the elements of.
 */
void reverseArray(T)(T[] array) {
    for (uint i = 0; i < array.length / 2; i++) {
        T tmp = array[i];
        array[i] = array[array.length - i - 1];
        array[array.length - i - 1] = tmp;
    }
}

/** 
 * Reads an unsigned integer value from a hex-string.
 * Params:
 *   chars = The characters to read from.
 * Returns: An optional unsigned integer.
 */
Optional!uint readHexString(const(char[]) chars) {
    uint value = 0;
    foreach (c; chars) {
        ubyte b;
        if (c >= '0' && c <= '9') {
            b = cast(ubyte) (c - '0');
        } else if (c >= 'a' && c <= 'f') {
            b = cast(ubyte) (c - 'a' + 10);
        } else if (c >= 'A' && c <= 'F') {
            b = cast(ubyte) (c - 'A' + 10);
        } else {
            return Optional!uint.init;
        }
        value = (value << 4) | (b & 0xF);
    }
    return Optional!uint(value);
}

unittest {
    char[10] buffer;
    buffer[0] = '4';
    assert(readHexString(buffer[0 .. 1]) == Optional!uint(4));
    buffer[0 .. 2] = cast(char[2]) "2A";
    assert(readHexString(buffer[0 .. 2]) == Optional!uint(42));
    buffer[0 .. 4] = cast(char[4]) "bleh";
    assert(readHexString(buffer[0 .. 4]) == Optional!uint.init);
    buffer[0 .. 6] = cast(char[6]) "4779CA";
    assert(readHexString(buffer[0 .. 6]) == Optional!uint(4_684_234));
    buffer[0] = '0';
    assert(readHexString(buffer[0 .. 1]) == Optional!uint(0));
}

/** 
 * Writes a hex string to a buffer for a given value.
 * Params:
 *   value = The unsigned integer value to write.
 *   buffer = The buffer to write to.
 * Returns: The number of characters that were written.
 */
uint writeHexString(uint value, char[] buffer) {
    const(char[16]) chars = "0123456789ABCDEF";
    if (value == 0) {
        buffer[0] = '0';
        return 1;
    }
    uint index = 0;
    while (value > 0) {
        buffer[index++] = chars[value & 0xF];
        value = value >>> 4;
    }
    reverseArray(buffer[0 .. index]);
    return index;
}

unittest {
    char[10] buffer;
    assert(writeHexString(4, buffer) == 1);
    assert(buffer[0] == '4', cast(string) buffer[0 .. 1]);
    
    assert(writeHexString(42, buffer) == 2);
    assert(buffer[0 .. 2] == cast(char[2]) "2A", cast(string) buffer[0 .. 2]);

    assert(writeHexString(0, buffer) == 1);
    assert(buffer[0] == '0', cast(string) buffer[0 .. 1]);

    assert(writeHexString(4_684_234, buffer) == 6);
    assert(buffer[0 .. 6] == cast(char[6]) "4779CA", cast(string) buffer[0 .. 6]);
}
