/** 
 * A collection of helper functions that augment the basic `read` and `write`
 * functions of input and output streams.
 */
module streams.functions;

import streams.primitives;

import std.traits;

/**
 * Continously reads an input stream into an in-memory buffer, until 0 elements
 * could be read, or an error occurs.
 * Params:
 *   stream = The stream to read from.
 *   bufferSize = The size of the internal buffer to use for reading.
 * Returns: The full contents of the stream.
 */
DataType[] readAll(StreamType, DataType)(
    ref StreamType stream,
    uint bufferSize = 8192
) if (isInputStream!(StreamType, DataType)) {
    import std.array : Appender, appender;
    Appender!(DataType[]) app = appender!(DataType[])();
    DataType[] buffer = new DataType[bufferSize];
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
    ubyte[] data = readAll!(FileInputStream, ubyte)(s1);
    assert(data.length == expectedSize);
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
void transferTo(InputStreamType, OutputStreamType, DataType)(
    ref InputStreamType input,
    ref OutputStreamType output,
    uint bufferSize = 8192
) if (isInputStream!(InputStreamType, DataType) && isOutputStream!(OutputStreamType, DataType)) {
    DataType[] buffer = new DataType[bufferSize];
    int itemsRead;
    while ((itemsRead = input.read(buffer)) > 0) {
        int written = output.write(buffer[0 .. itemsRead]);
        if (written != itemsRead) {
            throw new StreamException("Failed to transfer bytes.");
        }
    }
}

unittest {
    import streams;
    import std.file;

    auto sIn = FileInputStream("LICENSE");
    auto sOut = FileOutputStream("LICENSE-COPY");
    scope(exit) {
        std.file.remove("LICENSE-COPY");
    }
    transferTo!(FileInputStream, FileOutputStream, ubyte)(sIn, sOut);
    sIn.close();
    sOut.close();
    assert(getSize("LICENSE") == getSize("LICENSE-COPY"));
}
