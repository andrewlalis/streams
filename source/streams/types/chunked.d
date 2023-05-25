module streams.types.chunked;

import streams.primitives;
import streams.types.data;
import streams.utils;

private Optional!uint readHexString(const(char[]) chars) {
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
}

struct ChunkedEncodingInputStream(S) if (isByteInputStream!S) {
    private S* stream;
    private uint currentChunkSize = 0;
    private uint currentChunkIndex = 0;
    private bool endOfStream = false;

    this(ref S stream) {
        this.stream = &stream;
    }

    int readFromStream(ubyte[] buffer) {
        if (this.endOfStream) return 0;

        uint bytesRead = 0;
        uint bufferIndex = 0;

        while (bytesRead < buffer.length) {
            if (this.currentChunkSize == 0 || this.currentChunkIndex == this.currentChunkSize) {
                // Try to read the next chunk header.
                DataInputStream!S dIn = dataInputStreamFor(*this.stream);
                char[32] hexChars;
                uint charIdx = 0;
                while (!(charIdx >= 2 && hexChars[charIdx - 2] == '\r' && hexChars[charIdx - 1] == '\n')) {
                    DataReadResult!char result = dIn.readFromStream!char();
                    if (result.error.present) return result.error.value.lastStreamResult;
                    hexChars[charIdx++] = result.value.value;
                }
                Optional!uint chunkSize = readHexString(hexChars[0 .. charIdx - 2]);
                if (!chunkSize.present) return -1;
                if (chunkSize.value == 0) {
                    this.endOfStream = true;
                    return bytesRead;
                }
                this.currentChunkSize = chunkSize.value;
                this.currentChunkIndex = 0;
            }
            const uint bytesAvailable = this.currentChunkSize - this.currentChunkIndex;
            const uint spaceAvailable = cast(uint) buffer.length - bufferIndex;
            uint bytesToRead = bytesAvailable < spaceAvailable ? bytesAvailable : spaceAvailable;
            ubyte[] writableSlice = buffer[bufferIndex .. bufferIndex + bytesToRead];
            int result = this.stream.readFromStream(writableSlice);
            if (result != bytesToRead) return -1;
            bytesRead += bytesToRead;
            bufferIndex += bytesToRead;
            this.currentChunkIndex += bytesToRead;

            if (this.currentChunkIndex == this.currentChunkSize) {
                // Read the trailing \r\n after the chunk is done.
                ubyte[2] trail;
                int trailingResult = this.stream.readFromStream(trail);
                if (trailingResult != 2 || trail[0] != '\r' || trail[1] != '\n') return -1;
            }
        }

        return bytesRead;
    }
}

unittest {
    import streams.types.array;

    ubyte[] sample1 = cast(ubyte[]) "4\r\nWiki\r\n7\r\npedia i\r\nB\r\nn \r\nchunks.\r\n0\r\n";
    auto sIn1 = arrayInputStreamFor(sample1);
    auto cIn1 = ChunkedEncodingInputStream!(typeof(sIn1))(sIn1);
    ubyte[1024] buffer1;
    int result1 = cIn1.readFromStream(buffer1);
    assert(result1 > 0);
    assert(buffer1[0 .. result1] == "Wikipedia in \r\nchunks.");
}
