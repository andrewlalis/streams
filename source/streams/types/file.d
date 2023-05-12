module streams.types.file;

import std.stdio;

struct FileInputStream {
    private File file;

    this(File file) {
        this.file = file;
    }

    this(string filename) {
        this(File(filename, "rb"));
    }

    int read(ref ubyte[] buffer, uint offset, uint length) {
        ubyte[] slice = this.file.rawRead(buffer[offset .. offset + length]);
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

struct FileOutputStream {
    private File file;

    this(File file) {
        this.file = file;
    }

    this(string filename) {
        this(File(filename, "wb"));
    }

    int write(ref ubyte[] buffer, uint offset, uint length) {
        this.file.rawWrite(buffer[offset .. offset + length]);
        return length;
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