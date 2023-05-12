module streams.types.socket;

import std.socket;

struct SocketInputStream {
    private Socket socket;

    int read(ref ubyte[] buffer, uint offset, uint length) {
        ubyte[] slice = buffer[offset .. offset + length];
        ptrdiff_t receiveCount = this.socket.receive(slice);
        return cast(int) receiveCount;
    }

    void close() {
        this.socket.shutdown(SocketShutdown.BOTH);
        this.socket.close();
    }
}

unittest {
    import streams.primitives;

    assert(isInputStream!(SocketInputStream, ubyte));
    assert(isClosableStream!SocketInputStream);
}

struct SocketOutputStream {
    private Socket socket;

    int write(ref ubyte[] buffer, uint offset, uint length) {
        ptrdiff_t sendCount = this.socket.send(buffer[offset .. offset + length]);
        return cast(int) sendCount;
    }

    void close() {
        this.socket.shutdown(SocketShutdown.BOTH);
        this.socket.close();
    }
}

unittest {
    import streams.primitives;

    assert(isOutputStream!(SocketOutputStream, ubyte));
    assert(isClosableStream!SocketOutputStream);
}
