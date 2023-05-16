/** 
 * A collection of helper functions for working with streams.
 */
module streams.functions;

import streams.primitives : StreamType, isInputStream, isOutputStream;

version (D_BetterC) {} else {
    /**
     * Continously reads an input stream into an in-memory buffer, until 0 elements
     * could be read, or an error occurs.
     * TODO: Use custom memory allocator!
     * Params:
     *   stream = The stream to read from.
     * Returns: The full contents of the stream.
     */
    E[] readAll(S, E = StreamType!S, uint BufferSize = 4096)(
        ref S stream
    ) if (isInputStream!(S, E)) {
        import std.array : Appender, appender;
        Appender!(E[]) app = appender!(E[])();
        E[BufferSize] buffer;
        int itemsRead;
        while ((itemsRead = stream.readFromStream(buffer[])) > 0) {
            app ~= buffer[0 .. itemsRead];
        }
        return app[];
    }

    unittest {
        import streams;
        import std.file;

        auto s1 = FileInputStream("LICENSE");
        ulong expectedSize = getSize("LICENSE");
        ubyte[] data = readAll(s1);
        assert(data.length == expectedSize);
    }
}

/** 
 * Transfers elements from an input stream to an output stream, doing so
 * continuously until the input stream reads 0 elements or an error occurs.
 * The streams are not closed after transfer completes.
 * Params:
 *   input = The input stream to read from.
 *   output = The output stream to write to.
 * Returns: The total number of items transferred, or -1 in case of error.
 */
int transferTo(I, O, E = StreamType!I, uint BufferSize = 4096)(
    ref I input,
    ref O output
) if (isInputStream!(I, E) && isOutputStream!(O, E)) {
    E[BufferSize] buffer;
    int totalItemsTransferred = 0;
    int itemsRead;
    while ((itemsRead = input.readFromStream(buffer[])) > 0) {
        int written = output.writeToStream(buffer[0 .. itemsRead]);
        if (written != itemsRead) {
            return -1;
        }
        totalItemsTransferred += written;
    }
    return totalItemsTransferred;
}

unittest {
    import streams.types.array : arrayInputStreamFor, arrayOutputStreamFor;
    import streams.primitives : ErrorOutputStream;

    // Check that transferring does indeed work by transferring the LICENSE file to memory.
    char[12] expected = "Hello world!";
    auto sIn = arrayInputStreamFor!char(expected[]);
    auto sOut = arrayOutputStreamFor!char();
    assert(transferTo!(typeof(sIn), typeof(sOut), char, 4096)(sIn, sOut) == 12);
    assert(sOut.toArrayRaw() == expected);

    // Check that a stream exception is thrown if transfer fails.
    ubyte[3] data = [1, 2, 3];
    auto sIn2 = arrayInputStreamFor!ubyte(data);
    auto sOut2 = ErrorOutputStream!ubyte();
    assert(transferTo(sIn2, sOut2) == -1);
}
