# Streams

A collection of useful stream primitives and implementations. Designed to be a
candidate for inclusion in Phobos. The concept of a stream is of a component
that implements a `int read(T[] buffer)` or `int write(T[] buffer)` method for
some element type `T`.

Similar to [Phobos' ranges](https://dlang.org/phobos/std_range.html), streams
are defined and type-checked using a _primitives_ package that contains various
compile-time functions like `isInputRange` and `isOutputRange`. Take the
following example, where we define a simple input stream implementation for
reading from a file, and use it in a function that accepts any byte input
stream to collect the results in an array:

```d
struct FileInputStream {
    File f;

    int read(ubyte[] buffer) {
        ubyte[] slice = this.file.rawRead(buffer);
        return cast(int) slice.length;
    }
}

ubyte[] readToArray(S)(S stream) if (isInputStream!(S, ubyte)) {
    import std.array;
    ubyte[] buffer = new ubyte[8192];
    auto app = appender!(ubyte[]);
    int bytes;
    while ((bytes = stream.read(buffer)) > 0) {
        app ~= buffer[0 .. bytes];
    }
    return buffer;
}

unittest {
    import streams;
    assert(isInputStream!(FileInputStream, ubyte));
}
```

## Difference with Ranges

Phobos' concept of an **InputRange** relies on implicit buffering of results,
because of the contract it defines with `front()` needing to return the same
result in consecutive calls without calling `popFront()`. This doesn't map as
easily to many low-level resources, and also introduces additional cognitive
complexity to programmers who don't need that functionality.
