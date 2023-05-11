module ranges.file;

import ranges;

import std.stdio : File;

/** 
 * A readable range for reading from files.
 */
class FileInputRange : ReadableRange, ClosableRange {
    private File file;

    public this(File file) {
        this.file = file;
    }

    public this(string filename) {
        this(File(filename, "rb"));
    }

    alias read = ReadableRange.read;

    override int read(ref ubyte[] buffer, uint offset, uint length) {
        if (!this.file.isOpen() || buffer.length < 1 || offset + length > buffer.length) {
            return -1;
        }
        ubyte[] slice = buffer[offset .. offset + length];
        ubyte[] readSlice = this.file.rawRead(slice);
        return cast(int) readSlice.length;
    }

    public void close() {
        if (this.file.isOpen()) {
            this.file.close();
        }
    }
}

unittest {
    ReadableRange r = new FileInputRange("LICENSE");
    ubyte[] buffer = new ubyte[3];
    int byteCount = r.read(buffer);
    assert(byteCount == 3);
    assert(cast(string) buffer == "MIT");
    byteCount = r.read(buffer, 1);
    assert(byteCount == 2);
    assert(cast(string) buffer == "M L");
}

/** 
 * A writable range for writing to files.
 */
class FileOutputRange : WritableRange, ClosableRange {
    private File file;

    public this(File file) {
        this.file = file;
    }

    public this(string filename) {
        this(File(filename, "wb"));
    }

    alias write = WritableRange.write;

    override int write(ref ubyte[] buffer, uint offset, uint length) {
        if (!this.file.isOpen() || buffer.length < 1 || offset + length > buffer.length) {
            return -1;
        }
        ubyte[] slice = buffer[offset .. offset + length];
        this.file.rawWrite(slice);
        return cast(int) slice.length;
    }

    public void close() {
        if (this.file.isOpen()) {
            this.file.close();
        }
    }
}

unittest {
    import std.file;
    const TEMP_FILE = "test-file-output-range.txt";
    scope(exit) {
        std.file.remove(TEMP_FILE);
    }
    WritableRange r = new FileOutputRange(TEMP_FILE);
    ubyte[] buffer = cast(ubyte[]) "Hello world!";
    r.write(buffer);
    (cast(ClosableRange)r).close();
    assert(readText(TEMP_FILE) == "Hello world!");
}
