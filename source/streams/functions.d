/** 
 * A collection of helper functions for working with streams.
 */
module streams.functions;

import streams.primitives : StreamResult, StreamError, StreamType, isInputStream, isOutputStream;

/** 
 * Transfers elements from an input stream to an output stream, doing so
 * continuously until the input stream reads 0 elements or an error occurs.
 * The streams are not closed after transfer completes.
 * Params:
 *   input = The input stream to read from.
 *   output = The output stream to write to.
 * Returns: The result of the transfer operation.
 */
StreamResult transferTo(I, O, E = StreamType!I, uint BufferSize = 4096)(
    ref I input,
    ref O output
) if (isInputStream!(I, E) && isOutputStream!(O, E)) {
    E[BufferSize] buffer;
    int totalItemsTransferred = 0;
    while (true) {
        StreamResult readResult = input.readFromStream(buffer);
        if (readResult.hasError) return readResult; // Quit if reading fails.
        if (readResult.bytes == 0) break; // No more elements to read.

        StreamResult writeResult = output.writeToStream(buffer[0 .. readResult.bytes]);
        if (writeResult.hasError) return writeResult;
        if (writeResult.bytes != readResult.bytes) {
            return StreamResult(StreamError("Could not transfer all bytes.", writeResult.bytes));
        }

        totalItemsTransferred += writeResult.bytes;
    }
    return StreamResult(totalItemsTransferred);
}

unittest {
    import streams.types.array : arrayInputStreamFor, arrayOutputStreamFor;
    import streams.primitives;

    // Check that transferring does indeed work by transferring the LICENSE file to memory.
    char[12] expected = "Hello world!";
    auto sIn = arrayInputStreamFor!char(expected[]);
    auto sOut = arrayOutputStreamFor!char();
    assert(transferTo!(typeof(sIn), typeof(sOut), char, 4096)(sIn, sOut) == StreamResult(12));
    assert(sOut.toArrayRaw() == expected);

    // Check that a stream exception is thrown if transfer fails.
    ubyte[3] data = [1, 2, 3];
    auto sIn2 = arrayInputStreamFor!ubyte(data);
    auto sOut2 = ErrorOutputStream!ubyte();
    assert(transferTo(sIn2, sOut2).hasError);

    sIn2.reset();
    auto sOut3 = NoOpOutputStream!ubyte();
    assert(transferTo(sIn2, sOut3).hasError);
}
