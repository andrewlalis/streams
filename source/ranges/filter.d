module ranges.filter;

import ranges.base;

abstract class FilteredReadableRange : ReadableRange {
    protected ReadableRange range;

    this(ReadableRange range) {
        this.range = range;
    }

    override int read(ref ubyte[] buffer, uint offset, uint length) {
        return this.range.read(buffer, offset, length);
    }
}

abstract class FilteredWritableRange : WritableRange {
    protected WritableRange range;

    this(WritableRange range) {
        this.range = range;
    }

    override int write(ref ubyte[] buffer, uint offset, uint length) {
        return this.range.write(buffer, offset, length);
    }
}
