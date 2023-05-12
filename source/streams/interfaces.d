module streams.interfaces;

interface InputStream(DataType) {
    int read(ref DataType[] buffer, uint offset, uint length);
}

interface OutputStream(DataType) {
    int write(ref DataType[] buffer, uint offset, uint length);
}

interface ClosableStream {
    void close();
}

interface FlushableStream {
    void flush();
}
