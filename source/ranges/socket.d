module ranges.socket;

import ranges.base;

import std.socket;

class SocketInputRange : ReadableRange, ClosableRange {
    private Socket socket;

    this(Socket socket) {
        this.socket = socket;
    }

    alias read = ReadableRange.read;

    override int read(ref ubyte[] buffer, uint offset, uint length) {
        if (buffer.length < 1) return 0;
        ubyte[] slice = buffer[offset .. offset + length];
        ptrdiff_t result = this.socket.receive(slice);
        return cast(int) result;
    }

    void close() {
        if (this.socket.isAlive()) {
            this.socket.shutdown(SocketShutdown.BOTH);
            this.socket.close();
        }
    }
}

class SocketOutputRange : WritableRange, ClosableRange {
    private Socket socket;

    this(Socket socket) {
        this.socket = socket;
    }

    alias write = WritableRange.write;

    override int write(ref ubyte[] buffer, uint offset, uint length) {
        if (buffer.length < 1) return 0;
        ubyte[] slice = buffer[offset .. offset + length];
        ptrdiff_t result = this.socket.send(slice);
        return cast(int) result;
    }

    void close() {
        if (this.socket.isAlive()) {
            this.socket.shutdown(SocketShutdown.BOTH);
            this.socket.close();
        }
    }
}
