/** 
 * A collection of helper functions for working with streams.
 */
module streams.functions;

import streams.primitives;
import streams.utils;

/** 
 * Transfers elements from an input stream to an output stream, doing so
 * continuously until the input stream reads 0 elements or an error occurs.
 * The streams are not closed after transfer completes.
 * Params:
 *   input = The input stream to read from.
 *   output = The output stream to write to.
 *   maxElements = The maximum number of elements to transfer. Defaults to an
 *                 empty optional, meaning unlimited elements.
 * Returns: The result of the transfer operation.
 */
StreamResult transferTo(I, O, E = StreamType!I, uint BufferSize = 4096)(
    ref I input,
    ref O output,
    Optional!ulong maxElements = Optional!ulong.init
) if (isInputStream!(I, E) && isOutputStream!(O, E)) {
    E[BufferSize] buffer;
    uint totalItemsTransferred = 0;
    while (maxElements.notPresent || totalItemsTransferred < maxElements.value) {
        immutable uint elementsToRead = maxElements.present && (maxElements.value - totalItemsTransferred < BufferSize)
            ? cast(uint) (maxElements.value - totalItemsTransferred)
            : BufferSize;
        StreamResult readResult = input.readFromStream(buffer[0 .. elementsToRead]);
        if (readResult.hasError) return readResult; // Quit if reading fails.
        if (readResult.count == 0) break; // No more elements to read.

        StreamResult writeResult = output.writeToStream(buffer[0 .. readResult.count]);
        if (writeResult.hasError) return writeResult;
        if (writeResult.count != readResult.count) {
            return StreamResult(StreamError("Could not transfer all bytes to output stream.", writeResult.count));
        }

        totalItemsTransferred += writeResult.count;
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

    // Check that if we set a maximum number of elements, that we only read that many.
    int[10] buffer = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    auto sIn4 = arrayInputStreamFor(buffer);
    auto sOut4 = arrayOutputStreamFor!int();
    StreamResult result4 = transferTo(sIn4, sOut4, Optional!ulong(4));
    assert(result4 == StreamResult(4));
    assert(sOut4.toArrayRaw() == [1, 2, 3, 4]);
}

/** 
 * Reads all available elements from an input stream, and collects them in an
 * allocated buffer. If calling `hasData()` on the return value of this
 * function returns `true`, you need to free that data yourself, as it has been
 * allocated via `malloc`.
 * Params:
 *   stream = The stream to read from.
 * Returns: Either the data that was read, as a malloc'd buffer that should be
 * freed with `free(result.data.ptr)`, or a `StreamError` if something went
 * wrong.
 */
Either!(E[], "data", StreamError, "error") readAll(S, E = StreamType!S, uint BufferSize = 4096)(
    ref S stream
) if (isSomeInputStream!S) {
    E[BufferSize] buffer;
    AppendableBuffer!E app = AppendableBuffer!E(BufferSize, BufferAllocationStrategy.Doubling);
    while (true) {
        StreamResult readResult = stream.readFromStream(buffer);
        if (readResult.hasError) return Either!(E[], "data", StreamError, "error")(readResult.error);
        if (readResult.count == 0) break;
        app.appendItems(buffer[0 .. readResult.count]);
        if (readResult.count < BufferSize) break;
    }
    E[] copy = app.toArrayCopy();
    return Either!(E[], "data", StreamError, "error")(copy);
}

unittest {
    import streams.types.array;
    import core.stdc.stdlib : free;

    ubyte[12] data1 = cast(ubyte[12]) "Hello world!";
    auto sIn1 = arrayInputStreamFor(data1);
    auto result = readAll(sIn1);
    assert(result.hasData);
    free(result.data.ptr);

    const size = 10_000;
    int[size] data2;
    for (uint i = 0; i < size; i++) {
        data2[i] = i > 0 ? i - data2[i - 1] : i;
    }
    auto sIn2 = arrayInputStreamFor(data2);
    auto result2 = readAll(sIn2);
    assert(result2.hasData);
    assert(result2.data.length == size);
    free(result2.data.ptr);

    // Check that errors result in an error.
    auto sIn3 = ErrorInputStream!bool();
    auto result3 = readAll(sIn3);
    assert(result3.hasError);
}

/**
 * Reads exactly one element from an input stream.
 * Params:
 *   stream = The stream to read one element from.
 * Returns: Either the element, or an error.
 */
Either!(T, "element", StreamError, "error") readOne(S, T = StreamType!S)(ref S stream) if (isSomeInputStream!S) {
    T[1] buffer;
    StreamResult result = stream.readFromStream(buffer);
    if (result.hasError) return Either!(T, "element", StreamError, "error")(result.error);
    if (result.count != 1) return Either!(T, "element", StreamError, "error")(StreamError(
        "Did not read exactly 1 element.",
        result.count
    ));
    return Either!(T, "element", StreamError, "error")(buffer[0]);
}

unittest {
    import streams.types.array;

    ubyte[12] data1 = cast(ubyte[12]) "Hello world!";
    auto sIn1 = arrayInputStreamFor(data1);

    auto result = readOne(sIn1);
    assert(result.hasElement);
    assert(result.element == 'H');
    
    result = readOne(sIn1);
    assert(result.hasElement);
    assert(result.element == 'e');
    for (uint i = 0; i < 10; i++) {
        result = readOne(sIn1);
        assert(!result.hasError);
        assert(result.element == data1[i + 2]);
    }
    // Check that reading after we've exhausted the stream returns an error.
    result = readOne(sIn1);
    assert(result.hasError);
}

/** 
 * Writes exactly one element to an output stream.
 * Params:
 *   stream = The stream to write one element to.
 *   value = The value to write.
 * Returns: An optional stream error, which is present if writing failed.
 */
OptionalStreamError writeOne(S, T = StreamType!S)(ref S stream, T value) if (isSomeOutputStream!S) {
    T[1] buffer = [value];
    StreamResult result = stream.writeToStream(buffer);
    if (result.hasError) return OptionalStreamError(result.error);
    if (result.count != 1) return OptionalStreamError(StreamError(
        "Did not write exactly 1 element.",
        result.count
    ));
    return OptionalStreamError.init;
}

unittest {
    import streams.types.array;

    auto sOut1 = arrayOutputStreamFor!int();
    assert(writeOne(sOut1, 42).notPresent);
    assert(sOut1.toArrayRaw() == [42]);

    auto sOut2 = ErrorOutputStream!bool();
    assert(writeOne(sOut2, false).present);
}
