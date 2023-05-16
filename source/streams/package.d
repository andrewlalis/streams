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
public import streams.utils;

// Custom unittest runner for BetterC mode.
version (D_BetterC) {
    extern (C) void main() {
        runTests!(streams.primitives);
        runTests!(streams.utils);
        runTests!(streams.functions);
        runTests!(streams.interfaces);
        runTests!(streams.types.array);
        runTests!(streams.types.data);
        runTests!(streams.types.file);
        runTests!(streams.types.socket);
    }

    void runTests(alias mod)() {
        import core.stdc.stdio;
        printf("Running tests for module %s\n", cast(char*) mod.stringof);
        static foreach(u; __traits(getUnitTests, mod)) u();
    }
}
