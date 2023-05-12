/** 
 * A collection of helper functions that augment the basic `read` and `write`
 * functions of input and output streams.
 */
module streams.functions;

import streams.primitives;

import std.traits;

/**
 * Reads from a stream into a buffer, from the given offset until the end of
 * the buffer.
 * Params:
 *   stream = The stream to read from.
 *   buffer = The buffer to read to.
 *   offset = The offset in the buffer.
 * Returns: The number of elements to read.
 */
int read(StreamType, DataType)(
    ref StreamType stream,
    ref DataType[] buffer,
    uint offset
) if (isInputStream!(StreamType, DataType)) {
    if (buffer.length == 0) return 0;
    if (offset >= buffer.length) return -1;
    return stream.read(buffer, offset, cast(uint) buffer.length - offset);
}

unittest {
    import streams.factory;

    auto s1 = inputStreamFor([1, 2, 3, 4, 5]);
    int[] buffer = new int[2];
    assert(read(s1, buffer, 0) == 2);
    assert(buffer == [1, 2]);
    assert(read(s1, buffer, 1) == 1);
    assert(buffer == [1, 3]);
}

int read(StreamType, DataType)(
    ref StreamType stream,
    ref DataType[] buffer
) if (isInputStream!(StreamType, DataType)) {
    return read(stream, buffer, 0);
}

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
    while ((itemsRead = stream.read(buffer, 0, bufferSize)) > 0) {
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

int write(StreamType, DataType)(
    ref StreamType stream,
    ref DataType[] buffer,
    uint offset
) if (isOutputStream!(StreamType, DataType)) {
    if (buffer.length == 0) return 0;
    if (offset >= buffer.length) return -1;
    return stream.write(buffer, offset, cast(uint) buffer.length - offset);
}

int write(StreamType, DataType)(
    ref StreamType stream,
    ref DataType[] buffer
) if (isOutputStream!(StreamType, DataType)) {
    return write(stream, buffer, 0);
}

void transferTo(InputStreamType, OutputStreamType, DataType)(
    ref InputStreamType input,
    ref OutputStreamType output,
    uint bufferSize = 8192
) if (isInputStream!(InputStreamType, DataType) && isOutputStream!(OutputStreamType, DataType)) {
    DataType[] buffer = new DataType[bufferSize];
    int itemsRead;
    while ((itemsRead = input.read(buffer, 0, bufferSize)) > 0) {
        int written = output.write(buffer, 0, itemsRead);
        if (written != itemsRead) {
            throw new StreamException("Failed to transfer bytes.");
        }
    }
}

unittest {
    import streams;

    auto sIn = FileInputStream("LICENSE");
    auto sOut = FileOutputStream("LICENSE-COPY");
    scope(exit) {
        import std.file;
        std.file.remove("LICENSE-COPY");
    }
    transferTo!(FileInputStream, FileOutputStream, ubyte)(sIn, sOut);
}
