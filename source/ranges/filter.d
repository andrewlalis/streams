module ranges.filter;

import ranges.base;

abstract class FilteredReadableRange : ReadableRange {
    protected ReadableRange range;

    this(ReadableRange range) {
        this.range = range;
    }

    override int read(ref ubyte[] buffer, uint offset, uint length) {
        return 0;
    }
}