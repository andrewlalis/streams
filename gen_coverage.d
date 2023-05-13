#!/usr/bin/env dub
/+ dub.sdl:
    dependency "liblstparse" version="~>1.1.2"
+/

/**
 * Run this script to generate code coverage reports under the coverage/
 * directory.
 */
module gen_coverage;

import liblstparse.parser;

import std.process;
import std.file;
import std.path;
import std.stdio;

const double MIN_COVERAGE_PERCENT = 0.90;

int main() {
    auto result = executeShell("dub test --build=unittest-cov -- --DRT-covopt=\"dstpath:coverage\"");
    if (result.status != 0) {
        stderr.writefln!"Code coverage generation failed with code %d"(result.status);
        stderr.writeln(result.output);
        return result.status;
    }
    uint fileCount = 0;
    ulong lineCount = 0;
    ulong coveredLineCount = 0;
    foreach (DirEntry entry; dirEntries("coverage", SpanMode.shallow, false)) {
        import std.algorithm : canFind, endsWith;
        // Skip test-root and packages since they won't have any real code.
        if (canFind(entry.name, "_test_root") || endsWith(entry.name, "package.lst")) continue;
        LSTFile file = LSTFile(entry);
        fileCount++;
        writefln!"Coverage of %s: %d%%"(entry.name, file.totalCoverage);
        foreach (idx, line; file.lines) {
            if (!line.coverage.isNull) {
                uint coverage = line.coverage.get();
                if (coverage > 0) {
                    coveredLineCount++;
                } else {
                    writefln!"  ! L%04d -> %s"(idx, line.content);
                }
                lineCount++;
            }
        }
    }
    double coverageAvg = cast(double) coveredLineCount / lineCount;
    writefln!"Total coverage of %.2f%% of %d lines in %d files."(coverageAvg * 100, lineCount, fileCount);
    if (coverageAvg < MIN_COVERAGE_PERCENT) {
        stderr.writeln("Coverage is too low!");
        return 1;
    }
    return 0;
}
