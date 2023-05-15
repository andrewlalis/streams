/** 
 * A collection of helper functions that augment the basic `read` and `write`
 * functions of input and output streams.
 */
module streams.functions;

import streams.primitives;

import std.traits;

version (D_BetterC) {} else {
    /**
     * Continously reads an input stream into an in-memory buffer, until 0 elements
     * could be read, or an error occurs.
     * Params:
     *   stream = The stream to read from.
     *   bufferSize = The size of the internal buffer to use for reading.
     * Returns: The full contents of the stream.
     */
    E[] readAll(S, E = StreamType!S)(
        ref S stream,
        uint bufferSize = 8192
    ) if (isInputStream!(S, E)) {
        import std.array : Appender, appender;
        Appender!(E[]) app = appender!(E[])();
        E[] buffer = new E[bufferSize];
        int itemsRead;
        while ((itemsRead = stream.read(buffer)) > 0) {
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
 *   bufferSize = The size of the internal buffer to use for reading.
 */
void transferTo(I, O, E = StreamType!I)(
    ref I input,
    ref O output,
    uint bufferSize = 8192
) if (isInputStream!(I, E) && isOutputStream!(O, E)) {
    import core.stdc.stdlib : malloc, free;
    E* bufferPtr = cast(E*) malloc(bufferSize * E.sizeof);
    if (bufferPtr is null) {
        throw new Error("Failed to allocate buffer for transfering elements from input stream to output stream.");
    }
    scope(exit) {
        free(bufferPtr);
    }
    int itemsRead;
    while ((itemsRead = input.read(bufferPtr[0 .. bufferSize])) > 0) {
        int written = output.write(bufferPtr[0 .. itemsRead]);
        if (written != itemsRead) {
            throw new StreamException("Failed to transfer bytes.");
        }
    }
}

unittest {
    import streams;
    import std.file;

    // Check that transferring does indeed work by transferring the LICENSE file to memory.
    auto sIn = FileInputStream("LICENSE");
    auto sOut = byteArrayOutputStream();
    transferTo(sIn, sOut);
    sIn.close();
    assert(getSize("LICENSE") == sOut.toArrayRaw().length);
    assert(cast(ubyte[]) readText("LICENSE") == sOut.toArrayRaw());

    // Check that a stream exception is thrown if transfer fails.
    auto sIn2 = arrayInputStreamFor!ubyte([1, 2, 3]);
    auto sOut2 = ErrorOutputStream!ubyte();
    try {
        transferTo(sIn2, sOut2);
        assert(false, "Expected StreamException to be thrown.");
    } catch (StreamException e) {
        // This is expected.
    }
}
