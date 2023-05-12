module streams.types.file;

import std.stdio;

struct FileInputStream {
    private File file;

    int read(ref ubyte[] buffer, uint offset, uint length) {
        ubyte[] slice = this.file.rawRead(buffer[offset .. offset + length]);
        return cast(int) slice.length;
    }
}

struct FileOutputStream {
    private File file;

    int write(ref ubyte[] buffer, uint offset, uint length) {
        this.file.rawWrite(buffer[offset .. offset + length]);
        return length;
    }
}