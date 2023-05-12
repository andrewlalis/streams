module streams.functions;

import streams.primitives;

import std.traits;

/** 
 * Asserts that the given arguments are valid for a typical input or output
 * stream operation.
 * Params:
 *   buffer = A reference to the buffer.
 *   offset = The offset in the buffer.
 *   length = The length to read or write in the buffer.
 */
void assertValidStreamArgs(DataType)(ref DataType[] buffer, uint offset, uint length) {
    assert(
        buffer.length > 0,
        "Buffer length should be greater than 0."
    );
    assert(
        offset < buffer.length,
        "Offset should be less than the buffer's length."
    );
    assert(
        offset + length <= buffer.length,
        "Offset + length should be no greater than the buffer's length."
    );
}

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
