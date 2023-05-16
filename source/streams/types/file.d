/** 
 * Defines input and output streams for reading and writing files, using
 * `std.stdio.File` as the underlying resource.
 */
module streams.types.file;

import std.stdio : File;
import core.stdc.stdio;

version (D_BetterC) {} else {

/** 
 * A byte input stream that reads from a file. Makes use of the underlying
 * `fopen` and related C functions.
 */
struct FileInputStream {
    private File file;

    this(File file) {
        this.file = file;
    }

    this(string filename) {
        this(File(filename, "rb"));
    }

    int readFromStream(ubyte[] buffer) {
        ubyte[] slice = this.file.rawRead(buffer);
        return cast(int) slice.length;
    }

    void closeStream() {
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

    int writeToStream(ubyte[] buffer) {
        this.file.rawWrite(buffer);
        return cast(int) buffer.length;
    }

    void flushStream() {
        this.file.flush();
    }

    void closeStream() {
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
    sOut.flushStream();
    assert(getSize(FILENAME) == 0);
    auto dOut = dataOutputStreamFor(sOut);
    dOut.writeToStream!(char[5])("Hello");
    sOut.flushStream();
    assert(readText(FILENAME) == "Hello");
    f1.close();
    try {
        std.file.remove(FILENAME);
    } catch (FileException e) {
        stderr.writefln!"Failed to delete file %s: %s"(FILENAME, e.msg); // cov-ignore
    }
}

}
