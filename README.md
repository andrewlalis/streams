# Streams

A collection of useful stream primitives and implementations. Designed to be a
candidate for inclusion in Phobos. The concept of a stream is of a component
that implements a `int read(T[] buffer)` or `int write(T[] buffer)` method for
some element type `T`.

Similar to [Phobos' ranges](https://dlang.org/phobos/std_range.html), streams
are defined and type-checked using a _primitives_ package that contains various
compile-time functions like `isInputRange` and `isOutputRange`. Let's look at an example where we write some data to a socket using streams:

```d
import streams;

void sayHello(Socket socket) {
    auto outputStream = SocketOutputStream(socket);
    auto dataOutput = dataOutputStreamFor(outputStream);
    dataOutput.write!(char[5])("Hello");
}
```

Stream primitives are generally compatible with [BetterC](https://dlang.org/spec/betterc.html),
although there may be incompatibilities in various implementations where
dynamic arrays or exceptions are used. You may certainly write streams that are
safe, no-gc compatible, pure, and so on.

## Difference with Ranges

Phobos' concept of an **Input Range** relies on implicit buffering of results,
because of the contract it defines with `front()` needing to return the same
result in consecutive calls without calling `popFront()`. This doesn't map as
easily to many low-level resources, and also introduces additional cognitive
complexity to programmers who don't need that functionality.

This isn't to say that ranges aren't useful! They certainly are in many cases,
but the argument is that a simpler stream interface is more useful in IO-heavy
tasks or other cases where you simply want to read or write data to/from a
buffer.

Furthermore, streams of this nature are a common feature in many other
programming languages, and thus provides a bit of a "comfort zone" to help
welcome programmers.

For compatibility, this library provides the functions `asInputRange` and
`asOutputRange` to wrap an input stream as a Phobos input range and an output
stream as a Phobos output range, respectively. Note that due to the inherently
un-buffered nature of streams, these range implementations may not be as
performant as existing range implementations for certain resources.

## Development

Simply clone this repository, and ensure you have a recent version of D with
any compiler, and run `dub test` to test the library.

Documentation can be generated with `./gen_docs.d`, which internally uses
Adrdox to generate documentation at `generated-docs/`.

This codebase is expected to maintain a high code-quality, and while no
automated checks are in-place, it is expected that pull requests that add
significant new code adhere to the conventions already in use, and document
any new symbols you added.
