/**
 * A module that defines a basic format for input and output streams. A stream
 * is a component that defines a `read` or `write` function for reading from or
 * writing to some underlying resource, and possibly may define some other
 * capabilities such as closability or flushability.
 *
 * The [streams.primitives|primitives] module defines compile-time functions
 * that are used to check if an arbitrary type behaves as a stream in some
 * capacity.
 *
 * The [streams.functions|functions] module defines some common functions that
 * make it easier to work with streams.
 *
 * The [streams.types|types] module contains various pre-defined stream types
 * that can be used out-of-the-box for things like files, sockets, arrays, and
 * more.
 */
module streams;

public import streams.primitives;
public import streams.functions;
public import streams.types;
