/**
 * A module that defines a basic format for input and output streams. A stream
 * is a component that defines one or more methods for reading from or writing
 * to some underlying resource.
 */
module streams;

public import streams.primitives;
public import streams.functions;
public import streams.types;
public import streams.range;
public import streams.utils;

version (D_BetterC) {} else {
    public import streams.interfaces;
}
