module streams.types.chunked;

import streams.primitives : isByteInputStream, isByteOutputStream, isFlushableStream, isClosableStream;

/** 
 * An input stream for reading from a chunked-encoded stream of bytes.
 */
struct ChunkedEncodingInputStream(S) if (isByteInputStream!S) {
    private S* stream;
    private uint currentChunkSize = 0;
    private uint currentChunkIndex = 0;
    private bool endOfStream = false;

    this(ref S stream) {
        this.stream = &stream;
    }

    /** 
     * Reads from a chunked-encoded input stream in a way that respects chunk
     * boundaries.
     * Params:
     *   buffer = The buffer to read bytes into.
     * Returns: The number of bytes that were read, or -1 in case of error.
     */
    int readFromStream(ubyte[] buffer) {
        if (this.endOfStream) return 0;

        uint bytesRead = 0;
        uint bufferIndex = 0;

        while (bytesRead < buffer.length) {
            if (this.currentChunkSize == 0 || this.currentChunkIndex == this.currentChunkSize) {
                import streams.types.data : DataInputStream, dataInputStreamFor, DataReadResult;
                import streams.utils : Optional, readHexString;
                // Try to read the next chunk header.
                DataInputStream!S dIn = dataInputStreamFor(*this.stream);
                char[32] hexChars;
                uint charIdx = 0;
                // Keep reading until we reach the first \r\n.
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

/** 
 * An output stream for writing to a chunked-encoded stream of bytes.
 */
struct ChunkedEncodingOutputStream(S) if (isByteOutputStream!S) {
    private S* stream;

    this(ref S stream) {
        this.stream = &stream;
    }

    /** 
     * Writes a single chunk to the output stream.
     * Params:
     *   buffer = The data to write.
     * Returns: The number of bytes that were actually written, or -1 in case
     * of error. Note that this includes the bytes used to transmit the chunk
     * header and trailer bytes.
     */
    int writeToStream(ubyte[] buffer) {
        int headerBytes = this.writeChunkHeader(cast(uint) buffer.length);
        if (headerBytes < 0) return headerBytes;
        int bytesWritten = this.writeToStream(buffer);
        if (bytesWritten < 0) return bytesWritten;
        if (bytesWritten != buffer.length) return -1;
        int trailerBytes = this.writeChunkTrailer();
        if (trailerBytes < 0) return trailerBytes;
        return headerBytes + bytesWritten + trailerBytes;
    }

    /** 
     * Flushes the chunked-encoded stream by writing a final zero-size chunk
     * header and footer.
     */
    void flushStream() {
        int headerBytes = this.writeChunkHeader(0);
        assert(headerBytes == 3); // We expect: 0\r\n
        int trailerBytes = this.writeChunkTrailer();
        assert(trailerBytes == 2); // We expect: \r\n
        static if (isFlushableStream!S) {
            this.stream.flushStream();
        }
    }

    /** 
     * Closes the chunked-encoded stream, which also flushes the stream,
     * effectively writing a final zero-size chunk header and footer. Also
     * closes the underlying stream, if possible.
     */
    void closeStream() {
        this.flushStream();
        static if (isClosableStream!S) {
            this.stream.closeStream();
        }
    }

    private int writeChunkHeader(uint size) {
        import streams.utils : writeHexString;

        char[32] chars;
        uint sizeStrLength = writeHexString(size, chars);
        chars[sizeStrLength] = '\r';
        chars[sizeStrLength + 1] = '\n';
        int bytesWritten = this.stream.writeToStream(cast(ubyte[]) chars[0 .. sizeStrLength + 2]);
        if (bytesWritten < 0) return bytesWritten;
        if (bytesWritten != sizeStrLength + 2) return -1;
        return bytesWritten;
    }

    private int writeChunkTrailer() {
        int bytesWritten = this.stream.writeToStream(cast(ubyte[2]) "\r\n");
        if (bytesWritten < 0) return bytesWritten;
        if (bytesWritten != 2) return -1;
        return bytesWritten;
    }
}

unittest {
    import streams.primitives;
    import streams.types.array;

    auto sOut = byteArrayOutputStream();
    auto chunkedOut = ChunkedEncodingOutputStream!(typeof(sOut))(sOut);

    assert(isByteOutputStream!(typeof(chunkedOut)));
    assert(isFlushableStream!(typeof(chunkedOut)));
    assert(isClosableStream!(typeof(chunkedOut)));
}

// TODO: Add complete tests for both!
