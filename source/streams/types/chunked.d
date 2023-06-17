module streams.types.chunked;

import streams.primitives;

version (Have_slf4d) {import slf4d;}

import std.stdio;

/** 
 * An input stream for reading from a chunked-encoded stream of bytes.
 */
struct ChunkedEncodingInputStream(S) if (isByteInputStream!S) {
    private S stream;
    private uint currentChunkSize = 0;
    private uint currentChunkIndex = 0;
    private bool endOfStream = false;

    this(S stream) {
        this.stream = stream;
    }

    /** 
     * Reads from a chunked-encoded input stream in a way that respects chunk
     * boundaries.
     * Params:
     *   buffer = The buffer to read bytes into.
     * Returns: The number of bytes that were read, or -1 in case of error.
     */
    StreamResult readFromStream(ubyte[] buffer) {
        if (this.endOfStream) return StreamResult(0);

        uint bytesRead = 0;
        uint bufferIndex = 0;

        while (bytesRead < buffer.length) {
            if (this.currentChunkSize == 0 || this.currentChunkIndex == this.currentChunkSize) {
                import streams.types.data : DataInputStream, dataInputStreamFor, DataReadResult;
                import streams.utils : Optional, readHexString;
                // Try to read the next chunk header.
                version (Have_slf4d) {
                    traceF!"Reading chunked-encoding header from stream: %s"(typeof(this.stream).stringof);
                }
                // If we are using a pointer to a stream, we can just pass that to the data stream.
                static if (isPointerToStream!S) {
                    DataInputStream!S dIn = dataInputStreamFor(this.stream);
                } else { // Otherwise, we need to pass a reference to our stream to the data stream.
                    DataInputStream!(S*) dIn = dataInputStreamFor(&this.stream);
                }
                char[32] hexChars;
                uint charIdx = 0;
                // Keep reading until we reach the first \r\n.
                while (!(charIdx >= 2 && hexChars[charIdx - 2] == '\r' && hexChars[charIdx - 1] == '\n')) {
                    DataReadResult!char result = dIn.readFromStream!char();
                    if (result.hasError) return StreamResult(result.error);
                    hexChars[charIdx++] = result.value;
                }
                Optional!uint chunkSize = readHexString(hexChars[0 .. charIdx - 2]);
                if (!chunkSize.present) return StreamResult(StreamError("Invalid or missing chunk header size.", -1));
                if (chunkSize.value == 0) {
                    this.endOfStream = true;
                    return StreamResult(bytesRead);
                }
                this.currentChunkSize = chunkSize.value;
                this.currentChunkIndex = 0;
                version (Have_slf4d) {
                    traceF!"Read chunked-encoding header size of %d bytes."(chunkSize.value);
                }
            }
            const uint bytesAvailable = this.currentChunkSize - this.currentChunkIndex;
            const uint spaceAvailable = cast(uint) buffer.length - bufferIndex;
            uint bytesToRead = bytesAvailable < spaceAvailable ? bytesAvailable : spaceAvailable;
            ubyte[] writableSlice = buffer[bufferIndex .. bufferIndex + bytesToRead];
            StreamResult result = this.stream.readFromStream(writableSlice);
            if (result.hasError) return result;
            if (result.count != bytesToRead) return StreamResult(StreamError(
                "Could not read all bytes.", result.count
            ));
            bytesRead += bytesToRead;
            bufferIndex += bytesToRead;
            this.currentChunkIndex += bytesToRead;

            if (this.currentChunkIndex == this.currentChunkSize) {
                // Read the trailing \r\n after the chunk is done.
                version (Have_slf4d) {
                    trace("Reading chunked-encoding trailing carriage return and line feed.");
                }
                ubyte[2] trail;
                StreamResult trailingResult = this.stream.readFromStream(trail);
                if (trailingResult.hasError) return trailingResult;
                if (trailingResult.count != 2 || trail[0] != '\r' || trail[1] != '\n') {
                    return StreamResult(StreamError("Invalid chunk trailing.", trailingResult.count));
                }
            }
        }

        return StreamResult(bytesRead);
    }

    static if (isClosableStream!S) {
        OptionalStreamError closeStream() {
            return this.stream.closeStream();
        }
    }
}

unittest {
    import streams.types.array;

    ubyte[] sample1 = cast(ubyte[]) "4\r\nWiki\r\n7\r\npedia i\r\nB\r\nn \r\nchunks.\r\n0\r\n";
    auto sIn1 = arrayInputStreamFor(sample1);
    auto cIn1 = ChunkedEncodingInputStream!(typeof(sIn1))(sIn1);
    ubyte[1024] buffer1;
    StreamResult result1 = cIn1.readFromStream(buffer1);
    assert(result1.hasCount && result1.count > 0);
    assert(buffer1[0 .. result1.count] == "Wikipedia in \r\nchunks.");
}

ChunkedEncodingInputStream!S chunkedEncodingInputStreamFor(S)(S stream) if (isByteInputStream!S) {
    return ChunkedEncodingInputStream!(S)(stream);
}

/** 
 * An output stream for writing to a chunked-encoded stream of bytes.
 */
struct ChunkedEncodingOutputStream(S) if (isByteOutputStream!S) {
    private S stream;

    this(S stream) {
        this.stream = stream;
    }

    /** 
     * Writes a single chunk to the output stream.
     * Params:
     *   buffer = The data to write.
     * Returns: The number of bytes that were written, not including the chunk
     * header and trailer elements.
     */
    StreamResult writeToStream(ubyte[] buffer) {
        StreamResult headerResult = this.writeChunkHeader(cast(uint) buffer.length);
        if (headerResult.hasError) return headerResult;
        StreamResult chunkResult = this.stream.writeToStream(buffer);
        if (chunkResult.hasError) return chunkResult;
        if (chunkResult.count != buffer.length) return StreamResult(StreamError(
            "Could not write full chunk.",
            chunkResult.count
        ));
        StreamResult trailerResult = this.writeChunkTrailer();
        if (trailerResult.hasError) return trailerResult;
        return chunkResult;
    }

    /** 
     * Flushes the chunked-encoded stream by writing a final zero-size chunk
     * header and footer.
     */
    OptionalStreamError flushStream() {
        StreamResult headerResult = this.writeChunkHeader(0);
        if (headerResult.hasError) return OptionalStreamError(headerResult.error);
        StreamResult trailerResult = this.writeChunkTrailer();
        if (trailerResult.hasError) return OptionalStreamError(trailerResult.error);
        static if (isFlushableStream!S) {
            return this.stream.flushStream();
        } else {
            return OptionalStreamError.init;
        }
    }

    /** 
     * Closes the chunked-encoded stream, which also flushes the stream,
     * effectively writing a final zero-size chunk header and footer. Also
     * closes the underlying stream, if possible.
     */
    OptionalStreamError closeStream() {
        OptionalStreamError flushError = this.flushStream();
        if (flushError.present) return flushError;
        static if (isClosableStream!S) {
            return this.stream.closeStream();
        } else {
            return OptionalStreamError.init;
        }
    }

    private StreamResult writeChunkHeader(uint size) {
        import streams.utils : writeHexString;

        version (Have_slf4d) {
            traceF!"Writing chunked-encoding header for chunk of %d bytes."(size);
        }
        char[32] chars;
        uint sizeStrLength = writeHexString(size, chars);
        chars[sizeStrLength] = '\r';
        chars[sizeStrLength + 1] = '\n';
        StreamResult writeResult = this.stream.writeToStream(cast(ubyte[]) chars[0 .. sizeStrLength + 2]);
        if (writeResult.hasError) return writeResult;
        if (writeResult.count != sizeStrLength + 2) return StreamResult(StreamError(
            "Could not write full chunk header.", writeResult.count
        ));
        return writeResult;
    }

    private StreamResult writeChunkTrailer() {
        version (Have_slf4d) {
            trace("Writing chunked-encoding trailing carriage return and line feed.");
        }
        StreamResult writeResult = this.stream.writeToStream(cast(ubyte[2]) "\r\n");
        if (writeResult.hasError) return writeResult;
        if (writeResult.count != 2) return StreamResult(StreamError(
            "Could not write full chunk trailer.",
            writeResult.count
        ));
        return writeResult;
    }
}

unittest {
    import streams;

    auto sOut = byteArrayOutputStream();
    auto chunkedOut = ChunkedEncodingOutputStream!(typeof(sOut))(sOut);

    assert(isByteOutputStream!(typeof(chunkedOut)));
    assert(isFlushableStream!(typeof(chunkedOut)));
    assert(isClosableStream!(typeof(chunkedOut)));

    // To make things easier for ourselves, we'll test chunked encoding outside
    // of BetterC restrictions.

    version (D_BetterC) {} else {
        import std.stdio;
        import std.path;
        import std.file;
        import std.string;

        const filename = buildPath("source", "streams", "primitives.d");
        const filesize = getSize(filename);
        
        auto chunkedBuffer = byteArrayOutputStream();
        auto fIn = FileInputStream(toStringz(filename));
        auto sOut2 = ChunkedEncodingOutputStream!(typeof(&chunkedBuffer))(&chunkedBuffer);
        StreamResult result = transferTo(fIn, sOut2);
        assert(!result.hasError);
        sOut2.closeStream();
        ubyte[] chunkedFileContents = chunkedBuffer.toArray();
        assert(chunkedFileContents.length > filesize);

        auto chunkedIn = chunkedEncodingInputStreamFor(arrayInputStreamFor(chunkedFileContents));
        auto result2 = readAll(chunkedIn);
        assert(!result2.hasError, "Reading from chunked input stream failed: " ~ result2.error.message);
        assert(result2.data.length == filesize);
    }
}
