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
    import streams;
    import std.file;
    import std.stdio;

    assert(isOutputStream!(FileOutputStream, ubyte));
    assert(isClosableStream!FileOutputStream);
    assert(isFlushableStream!FileOutputStream);

    // Test flushing of file.
    const FILENAME = "test-file-flush";
    File f1 = File(FILENAME, "wb");
    auto sOut = FileOutputStream(f1);
    sOut.flush();
    assert(getSize(FILENAME) == 0);
    auto dOut = dataOutputStreamFor(sOut);
    dOut.write!(char[5])("Hello");
    sOut.flush();
    assert(readText(FILENAME) == "Hello");
    f1.close();
    try {
        std.file.remove(FILENAME);
    } catch (FileException e) {
        stderr.writefln!"Failed to delete file %s: %s"(FILENAME, e.msg);
    }
}