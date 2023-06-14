/**
 * Container module with sub-modules that define stream implementations for
 * various use cases.
 */
module streams.types;

public import streams.types.array;
public import streams.types.buffered;
public import streams.types.chunked;
public import streams.types.concat;
public import streams.types.data;
public import streams.types.file;

version (D_BetterC) {} else {
    public import streams.types.socket;
}
