/** 
 * Defines input and output streams for reading from and writing to sockets,
 * using the `Socket` class from `std.socket` as the underlying resource.
 */
module streams.types.socket;

import streams.primitives;

version (D_BetterC) {} else {

import std.socket;

/** 
 * A byte input stream for reading from a socket.
 */
struct SocketInputStream {
    private Socket socket;

    /** 
     * Receives up to `buffer.length` bytes from the socket, and stores them in
     * `buffer`.
     * Params:
     *   buffer = The buffer to store received bytes in.
     * Returns: The number of bytes read, or -1 in case of error.
     */
    StreamResult readFromStream(ubyte[] buffer) {
        ptrdiff_t receiveCount = this.socket.receive(buffer);
        if (receiveCount == Socket.ERROR) return StreamResult(StreamError("Socket error.", cast(int) receiveCount));
        return StreamResult(cast(uint) receiveCount);
    }

    /** 
     * Shuts down and closes this stream's underlying socket.
     */
    OptionalStreamError closeStream() {
        this.socket.shutdown(SocketShutdown.BOTH);
        this.socket.close();
        return OptionalStreamError.init;
    }
}

/** 
 * A byte output stream for writing to a socket.
 */
struct SocketOutputStream {
    private Socket socket;

    /** 
     * Writes bytes from `buffer` to the socket.
     * Params:
     *   buffer = The buffer to write bytes from.
     * Returns: The number of bytes written, or -1 in case of error.
     */
    StreamResult writeToStream(ubyte[] buffer) {
        ptrdiff_t sendCount = this.socket.send(buffer);
        if (sendCount == Socket.ERROR) return StreamResult(StreamError("Socket error.", cast(int) sendCount));
        return StreamResult(cast(uint) sendCount);
    }

    /** 
     * Shuts down and closes this stream's underlying socket.
     */
    OptionalStreamError closeStream() {
        this.socket.shutdown(SocketShutdown.BOTH);
        this.socket.close();
        return OptionalStreamError.init;
    }
}

unittest {
    import streams.primitives;

    assert(isByteInputStream!SocketInputStream);
    assert(isClosableStream!SocketInputStream);

    assert(isByteOutputStream!SocketOutputStream);
    assert(isClosableStream!SocketOutputStream);

    Socket[2] pair = socketPair();
    auto sIn = SocketInputStream(pair[0]);
    auto sOut = SocketOutputStream(pair[1]);
    assert(sOut.writeToStream([1, 2, 3]) == StreamResult(3));
    ubyte[] buffer = new ubyte[8192];
    assert(sIn.readFromStream(buffer) == StreamResult(3));
    assert(buffer[0 .. 3] == [1, 2, 3]);
    sIn.closeStream();
    sOut.closeStream();
    assert(sIn.readFromStream(buffer).hasError);
    assert(sOut.writeToStream([4, 5, 6]).hasError);
}

}
