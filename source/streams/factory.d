/**
 * Definitions for some methods for obtaining streams to common resources.
 */
module streams.factory;

import streams.primitives;
import streams.types.data;
import streams.types.array;

/** 
 * Creates and returns an array input stream wrapped around the given array
 * of elements.
 * Params:
 *   array = The array to stream.
 * Returns: The array input stream.
 */
ArrayInputStream!T inputStreamFor(T)(T[] array) {
    return ArrayInputStream!T(array);
}

/** 
 * Creates and returns a data input stream that's wrapped around the given
 * byte input stream.
 * Params:
 *   stream = The stream to wrap in a data input stream.
 * Returns: The data input stream.
 */
DataInputStream!S dataInputStreamFor(S)(
    ref S stream
) if (isByteInputStream!S) {
    return DataInputStream!S(&stream);
}

/** 
 * Creates and returns a data output stream that's wrapped around the given
 * byte output stream.
 * Params:
 *   stream = The stream to wrap in a data output stream.
 * Returns: The data output stream.
 */
DataOutputStream!S dataOutputStreamFor(S)(
    ref S stream
) if (isByteOutputStream!S) {
    return DataOutputStream!S(&stream);
}
