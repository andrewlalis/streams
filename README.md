# Streams

![DUB](https://img.shields.io/dub/dt/streams)
![GitHub Workflow Status (with branch)](https://img.shields.io/github/actions/workflow/status/andrewlalis/streams/run-tests.yml?branch=main&label=tests)
![DUB](https://img.shields.io/dub/l/streams)

A collection of useful stream primitives and implementations. *Streams* come in
two flavors:
- **Input** streams must define a function `StreamResult readFromStream(E[] buffer)`
for reading elements from a data source and storing them in `buffer`.
- **Output** streams must define a function `StreamResult writeToStream(E[] buffer)`
for writing elements from `buffer` to a data sink.

Features:
- Full BetterC compatibility
- Simple, extensible interface
- Seamless conversion between streams and ranges
- Fully documented API
- Many basic stream types are included:
    - Array input streams for reading from arrays, and array output streams to
    write to an in-memory array buffer.
    - Buffered input and output streams that buffer reads and writes to a
    wrapped stream.
    - File streams that use C's `fopen` and associated functions so for BetterC
    compatibility.
    - Socket streams (only available outside of BetterC mode).
    - Data serialization and deserialization streams, for reading and writing
    primitive values and arrays using configured endianness.
    - Chunked-encoded streams for reading and writing chunked data according to
    [RFC-9112, section 7.1](https://datatracker.ietf.org/doc/html/rfc9112#section-7.1).
    *Currently doesn't support trailer fields.*

Similar to [Phobos' ranges](https://dlang.org/phobos/std_range.html), streams
are defined and type-checked using a _primitives_ package that contains various
compile-time functions like `isInputStream` and `isOutputStream`.

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

### Range Compatibility

- To convert a range to a stream: `auto stream = asStream(range);` You can also
use `asInputStream` and `asOutputStream` to be more explicit when dealing with
things that behave as both an input and output range.
- To convert a stream to a range: `auto range = asRange(stream);` You can also
use `asInputRange` and `asOutputRange` to be more explicit when dealing with
streams that implement both input and output functions.

## Development

Simply clone this repository, and ensure you have a recent version of D with
any compiler, and run `dub test` to test the library.

For testing the library's *BetterC* compatibility, run `dub test --config=betterC`.

Documentation can be generated with `./gen_docs.d`, which internally uses
Adrdox to generate documentation at `generated-docs/`.

Tests and coverage are run automatically with GitHub Actions. See `gen_coverage.d`
for a look at how coverage is computed in detail, but essentially:

1. We generate coverage `.lst` files using the standard compiler unittest
coverage feature.
2. The `.lst` files are parsed, and lines with `// cov-ignore` comments are
ignored.
3. We compute the % of lines covered, and if it's below some threshold, fail.

> Note for MacOSX v13 developers: run this before running tests:
> `export MACOSX_DEPLOYMENT_TARGET=12`
