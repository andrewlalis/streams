module streams.types.socket;

import std.socket;

struct SocketInputStream {
    private Socket socket;

    int read(ubyte[] buffer) {
        ptrdiff_t receiveCount = this.socket.receive(buffer);
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

    int write(ubyte[] buffer) {
        ptrdiff_t sendCount = this.socket.send(buffer);
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
