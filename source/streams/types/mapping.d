/**
 * This module defines "mapping" input and output streams, which map elements
 * of a wrapped stream to another type. For example, a mapping input stream
 * could wrap around an input stream of strings, and parse each one as an int.
 *
 * Mapping streams generally operate using a templated function alias; that is,
 * you provide a function at compile-time, and a stream on which to operate.
 * The mapping function should take a single argument, and produce a result of
 * any type. However, if your function returns a `MapResult` type (as defined
 * in this module), the mapping streams will acknowledge any stream errors that
 * occur.
 */
module streams.types.mapping;

import streams.primitives;
import streams.utils;

/**
 * A return type to use when a mapping function could encounter an error.
 * Mapping streams have a special case to treat this return type.
 */
alias MapResult(E) = Either!(StreamError, "error", E, "element");

/**
 * An input stream that wraps another stream, and applies a function to each
 * element read from that stream.
 */
struct MappingInputStream(alias f, S) if (isSomeInputStream!S && isMappingFunction!(typeof(f), StreamType!S)) {
    alias Ein = StreamType!S;
    alias Eout = MappingFunctionReturnType!(typeof(f));
    
    private S stream;

    this(S stream) {
        this.stream = stream;
    }

    StreamResult readFromStream(Eout[] buffer) {
        Ein[1] inputBuffer;
        for (uint i = 0; i < buffer.length; i++) {
            StreamResult result = this.stream.readFromStream(inputBuffer);
            if (result.hasError) return result;
            if (result.count == 0) return StreamResult(i);
            static if (returnsMapResult!(typeof(f))) {
                MapResult!Eout mapResult = f(inputBuffer[0]);
                if (mapResult.hasError) return StreamResult(mapResult.error);
                buffer[i] = mapResult.element;
            } else {
                buffer[i] = f(inputBuffer[0]);
            }
        }
        return StreamResult(cast(uint) buffer.length);
    }
}

/**
 * Creates a mapping input stream that applies the function `f` to all elements
 * read from the stream.
 * Params:
 *   stream = The stream to wrap.
 * Returns: A mapping input stream.
 */
MappingInputStream!(f, S) mappingInputStreamFor(alias f, S)(
    S stream
) if (isSomeInputStream!S && isMappingFunction!(typeof(f), StreamType!S)) {
    return MappingInputStream!(f, S)(stream);
}

unittest {
    import streams;
    int[3] buf1 = [1, 2, 3];
    auto sIn1 = arrayInputStreamFor(buf1);
    auto map1 = MappingInputStream!((int a) => a + 1, typeof(&sIn1))(&sIn1);
    assert(isInputStream!(typeof(map1), int));
    int[3] bufOut1;
    assert(map1.readFromStream(bufOut1) == StreamResult(3));
    assert(bufOut1 == [2, 3, 4]);
    sIn1.reset();

    import std.stdio;
    // Test that the function helper works too.
    auto map2 = mappingInputStreamFor!((int a) => a - 1)(&sIn1);
    int[3] bufOut2;
    assert(map2.readFromStream(bufOut2) == StreamResult(3));
    assert(bufOut2 == [0, 1, 2]);
}

/**
 * An output stream that applies a function to each element that's written to
 * it before writing to the underlying stream.
 */
struct MappingOutputStream(alias f, S) if (
    isSomeOutputStream!S &&
    isSomeMappingFunction!(typeof(f)) &&
    is(MappingFunctionReturnType!(typeof(f)) == StreamType!S)
) {
    alias Ein = MappingFunctionInputType!(typeof(f));
    alias Eout = StreamType!S;

    private S stream;

    this(S stream) {
        this.stream = stream;
    }

    StreamResult writeToStream(Ein[] buffer) {
        Eout[1] outputBuffer = [Eout.init];
        foreach (element; buffer) {
            static if (returnsMapResult!(typeof(f))) {
                MapResult!Eout mapResult = f(element);
                if (mapResult.hasError) return StreamResult(mapResult.error);
                outputBuffer[0] = mapResult.element;
            } else {
                outputBuffer[0] = f(element);
            }
            StreamResult writeResult = this.stream.writeToStream(outputBuffer);
            if (writeResult.hasError) return writeResult;
            if (writeResult.count != 1) {
                return StreamResult(StreamError("Failed to write element.", writeResult.count));
            }
        }
        return StreamResult(cast(uint) buffer.length);
    }
}

/**
 * Creates a mapping output stream that applies the function `f` to all elements
 * written to the stream.
 * Params:
 *   stream = The stream to wrap.
 * Returns: A mapping output stream.
 */
MappingOutputStream!(f, S) mappingOutputStreamFor(alias f, S)(
    S stream
) if (
    isSomeOutputStream!S &&
    isSomeMappingFunction!(typeof(f)) &&
    is(MappingFunctionReturnType!(typeof(f)) == StreamType!S)
) {
    return MappingOutputStream!(f, S)(stream);
}

unittest {
    import streams;
    int[3] buf1 = [1, 2, 3];
    auto sOut1 = arrayOutputStreamFor!double;
    auto mapOut1 = mappingOutputStreamFor!((int a) => 0.25 * a)(&sOut1);
    assert(isOutputStream!(typeof(mapOut1), int));
    assert(mapOut1.writeToStream(buf1) == StreamResult(3));
    assert(sOut1.toArrayRaw() == [0.25, 0.5, 0.75]);

    // Test writing to an error stream.
    auto sOut2 = ErrorOutputStream!ubyte();
    auto mapOut2 = mappingOutputStreamFor!((ulong a) => cast(ubyte) (a & 0xFF))(&sOut2);
    ulong[2] buf2 = [123, 456];
    assert(mapOut2.writeToStream(buf2).hasError);
    // Also for a stream that doesn't write anything.
    auto sOut3 = NoOpOutputStream!ubyte();
    auto mapOut3 = mappingOutputStreamFor!((ulong a) => cast(ubyte) (a & 0xFF))(&sOut3);
    assert(mapOut3.writeToStream(buf2).hasError);
}

private bool isSomeMappingFunction(F)() {
    import std.traits : isSomeFunction, ReturnType, isInstanceOf, TemplateArgsOf, Parameters;
    static if (isSomeFunction!F) {
        static if (Parameters!(F).length == 1) {
            return !is(ReturnType!F == void);
        } else {
            return false;
        }
    } else {
        return false;
    }
}

unittest {
    auto f1 = (int a) => cast(char) a;
    assert(isSomeMappingFunction!(typeof(f1)));
    auto f2 = (ubyte u) => MapResult!bool(true);
    assert(isSomeMappingFunction!(typeof(f2)));
    auto f3 = () => -1;
    assert(!isSomeMappingFunction!(typeof(f3)));
}

private template MappingFunctionInputType(F) if (isSomeMappingFunction!F) {
    import std.traits : Parameters;
    alias MappingFunctionInputType = Parameters!(F)[0];
}

private bool isMappingFunction(F, Ein)() if (isSomeMappingFunction!F) {
    return is(MappingFunctionInputType!F == Ein);
}

private template MappingFunctionReturnType(F) if (isSomeMappingFunction!F) {
    import std.traits : ReturnType, TemplateArgsOf, isInstanceOf;
    alias r = ReturnType!F;
    static if (isInstanceOf!(Either, r)) {
        alias args = TemplateArgsOf!r;
        static if (args[1] == "element") {
            alias MappingFunctionReturnType = args[0];
        } else {
            alias MappingFunctionReturnType = args[2];
        }
    } else {
        alias MappingFunctionReturnType = r;
    }
}

unittest {
    auto f1 = (int a) => 0.5f * a;
    assert(is(MappingFunctionReturnType!(typeof(f1)) == float));
    auto f2 = (bool b) => !b;
    assert(is(MappingFunctionReturnType!(typeof(f2)) == bool));
    auto f3 = (ubyte b) => MapResult!char('A');
    assert(is(MappingFunctionReturnType!(typeof(f3)) == char));
}

private bool returnsMapResult(F)() if (isSomeMappingFunction!F) {
    import std.traits : ReturnType, isInstanceOf;
    alias r = ReturnType!F;
    return isInstanceOf!(Either, r);
}

unittest {
    auto f1 = (int a) => MapResult!bool(a > 5);
    assert(returnsMapResult!(typeof(f1)));
    auto f2 = (bool b) => !b;
    assert(!returnsMapResult!(typeof(f2)));
}
