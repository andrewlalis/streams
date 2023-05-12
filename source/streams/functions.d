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
    StreamType stream,
    ref DataType[] buffer,
    uint offset
) if (isInputStream!(StreamType, DataType)) {
    if (buffer.length == 0) return 0;
    if (offset >= buffer.length) return -1;
    return stream.read(buffer, offset, cast(uint) buffer.length - offset);
}

int read(StreamType, DataType)(
    StreamType stream,
    ref DataType[] buffer
) if (isInputStream!(StreamType, DataType)) {
    return read(stream, buffer, 0);
}

DataType[] readAll(StreamType, DataType)(
    StreamType stream,
    uint bufferSize = 8192
) if (isInputStream!(StreamType, DataType)) {
    import std.array : Appender, appender;
    Appender!DataType app = appender();
    DataType[] buffer = new DataType[bufferSize];
    int itemsRead;
    while ((itemsRead = stream.read(buffer)) > 0) {
        app ~= buffer[0 .. itemsRead];
    }
    return app[];
}

int write(StreamType, DataType)(
    StreamType stream,
    ref DataType[] buffer,
    uint offset
) if (isOutputStream!(StreamType, DataType)) {
    if (buffer.length == 0) return 0;
    if (offset >= buffer.length) return -1;
    return stream.write(buffer, offset, cast(uint) buffer.length - offset);
}

int write(StreamType, DataType)(
    StreamType stream,
    ref DataType[] buffer
) if (isOutputStream!(StreamType, DataType)) {
    return write(stream, buffer, 0);
}
