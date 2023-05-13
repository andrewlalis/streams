/**
 * A module that defines a basic format for input and output streams. A stream
 * is a component that defines a `read` or `write` function for reading from or
 * writing to some underlying resource, and possibly may define some other
 * capabilities such as closability or flushability.
 */
module streams;

public import streams.primitives;
public import streams.functions;
public import streams.types;
public import streams.interfaces;
