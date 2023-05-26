/** 
 * Defines input and output streams for reading and writing files using C's
 * stdio functions as a basis.
 */
module streams.types.file;

import streams.primitives;

import core.stdc.stdio : fopen, fclose, fread, fwrite, fflush, feof, ferror, FILE;

/** 
 * A byte input stream that reads from a file. Makes use of the underlying
 * `fopen` and related C functions.
 */
struct FileInputStream {
    private FILE* filePtr;

    this(FILE* filePtr) {
        assert(filePtr !is null);
        this.filePtr = filePtr;
    }

    this(const(char*) filename) {
        this(fopen(filename, "rb"));
    }

    StreamResult readFromStream(ubyte[] buffer) {
        if (this.filePtr is null) {
            return StreamResult(StreamError("File is not open.", -1));
        }
        size_t bytesRead = fread(buffer.ptr, ubyte.sizeof, buffer.length, this.filePtr);
        if (bytesRead != buffer.length && ferror(this.filePtr) != 0) {
            return StreamResult(StreamError("An error occurred while reading.", cast(int) bytesRead)); // cov-ignore
        }
        return StreamResult(cast(uint) bytesRead);
    }

    OptionalStreamError closeStream() {
        if (this.filePtr !is null) {
            fclose(this.filePtr);
            this.filePtr = null;
        }
        return OptionalStreamError.init;
    }
}

unittest {
    import streams.primitives : isInputStream, isClosableStream;
    import streams.types.array : ArrayOutputStream, byteArrayOutputStream;
    import streams.functions : transferTo;
    import core.stdc.stdio;

    assert(isInputStream!(FileInputStream, ubyte));
    assert(isClosableStream!FileInputStream);

    // Test reading from a file.
    ArrayOutputStream!ubyte sOut = byteArrayOutputStream();
    FILE* fp1 = fopen("LICENSE", "rb");
    fseek(fp1, 0L, SEEK_END);
    ulong expectedFilesize = ftell(fp1);
    fclose(fp1);
    FileInputStream fIn = FileInputStream("LICENSE");
    transferTo(fIn, sOut);
    fIn.closeStream();
    // Check that after closing the stream, the file pointer is nullified.
    assert(fIn.filePtr is null);
    ubyte[3] tempBuffer;
    assert(fIn.readFromStream(tempBuffer).hasError); // Reading after closed should error.

    // Check that the number of bytes read matches.
    assert(sOut.toArrayRaw().length == expectedFilesize);

    // Check that the read was correct manually. We need a no-gc way to read
    // the file contents without using the FileInputStream impl.
    import core.stdc.stdlib;
    fp1 = fopen("LICENSE", "rb");
    assert(fp1 !is null);
    ubyte* buffer = cast(ubyte*) malloc(expectedFilesize * ubyte.sizeof);
    size_t bytesRead = fread(buffer, ubyte.sizeof, expectedFilesize, fp1);
    assert(bytesRead == expectedFilesize);
    fclose(fp1);

    assert(sOut.toArrayRaw() == buffer[0 .. expectedFilesize]);
    free(buffer);
}

/** 
 * A byte output stream that writes to a file.
 */
struct FileOutputStream {
    private FILE* filePtr;

    this(FILE* filePtr) {
        assert(filePtr !is null);
        this.filePtr = filePtr;
    }

    this(const(char*) filename) {
        this(fopen(filename, "wb"));
    }

    StreamResult writeToStream(ubyte[] buffer) {
        if (this.filePtr is null) {
            return StreamResult(StreamError("File is not open.", -1));
        }
        size_t bytesWritten = fwrite(buffer.ptr, ubyte.sizeof, buffer.length, this.filePtr);
        if (bytesWritten < buffer.length && ferror(this.filePtr) != 0) {
            return StreamResult(StreamError("An error occurred while writing.", cast(int) bytesWritten)); // cov-ignore
        }
        return StreamResult(cast(uint) bytesWritten);
    }

    OptionalStreamError flushStream() {
        if (this.filePtr !is null) {
            fflush(this.filePtr);
        }
        return OptionalStreamError.init;
    }

    OptionalStreamError closeStream() {
        if (this.filePtr !is null) {
            fclose(this.filePtr);
            this.filePtr = null;
        }
        return OptionalStreamError.init;
    }
}

unittest {
    import streams.primitives : isOutputStream, isClosableStream, isFlushableStream;
    import core.stdc.stdio;
    import core.stdc.stdlib;


    assert(isOutputStream!(FileOutputStream, ubyte));
    assert(isClosableStream!FileOutputStream);
    assert(isFlushableStream!FileOutputStream);

    // Test flushing of file.
    const(char*) FILENAME = "test-file-flush";
    scope(exit) {
        int result = remove(FILENAME);
        assert(result == 0);
    }

    FileOutputStream fOut = FileOutputStream(FILENAME);
    char[5] content = ['H', 'e', 'l', 'l', 'o'];
    fOut.writeToStream(cast(ubyte[5]) content);
    
    // Check that the file doesn't exist yet, when we haven't flushed.
    FILE* fp1 = fopen(FILENAME, "rb");
    ubyte* buffer = cast(ubyte*) malloc(1000 * ubyte.sizeof);
    size_t bytesRead = fread(buffer, ubyte.sizeof, 1000, fp1);
    assert(bytesRead == 0);
    assert(feof(fp1) != 0);
    assert(ferror(fp1) == 0);
    fclose(fp1);

    // Flush and check that the contents have updated.
    fOut.flushStream();
    fp1 = fopen(FILENAME, "rb");
    assert(fp1 !is null);
    bytesRead = fread(buffer, ubyte.sizeof, 1000, fp1);
    assert(bytesRead == 5);
    fclose(fp1);
    assert(buffer[0 .. 5] == content);

    // Check that the file pointer is closed upon closing the stream.
    fOut.closeStream();
    assert(fOut.filePtr is null);
    assert(fOut.writeToStream(cast(ubyte[5]) content).hasError);
}
