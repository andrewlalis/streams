module streams.functions;

import streams.primitives;

import std.traits;

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
