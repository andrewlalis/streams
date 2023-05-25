module streams.error;

import streams.utils;

/** 
 * An error that occurred during a stream operation, which includes a short
 * message, as well as an integer code which is usually the last stream
 * operation return code.
 */
struct StreamError {
    const(char[]) message;
    const int code;
}

/** 
 * Either a number of bytes that have been read or written, or a stream error,
 * as a common result type for many stream operations.
 */
alias StreamResult = Either!(uint, "bytes", StreamError, "error");
