/** 
 * Defines input and output streams for reading and writing files, using
 * `std.stdio.File` as the underlying resource.
 */
module streams.types.file;

import std.stdio : File;

/** 
 * A byte input stream that reads from a file.
 */
struct FileInputStream {
    private File file;

    this(File file) {
        this.file = file;
    }

    this(string filename) {
        this(File(filename, "rb"));
    }

    int read(ubyte[] buffer) {
        ubyte[] slice = this.file.rawRead(buffer);
        return cast(int) slice.length;
    }

    void close() {
        if (this.file.isOpen()) {
            this.file.close();
        }
    }
}

unittest {
    import streams.primitives;

    assert(isInputStream!(FileInputStream, ubyte));
    assert(isClosableStream!FileInputStream);
}

/** 
 * A byte output stream that writes to a file.
 */
struct FileOutputStream {
    private File file;

    this(File file) {
        this.file = file;
    }

    this(string filename) {
        this(File(filename, "wb"));
    }

    int write(ubyte[] buffer) {
        this.file.rawWrite(buffer);
        return cast(int) buffer.length;
    }

    void flush() {
        this.file.flush();
    }

    void close() {
        if (this.file.isOpen()) {
            this.file.close();
        }
    }
}

unittest {
    import streams.primitives;

    assert(isOutputStream!(FileOutputStream, ubyte));
    assert(isClosableStream!FileOutputStream);
    assert(isFlushableStream!FileOutputStream);
}