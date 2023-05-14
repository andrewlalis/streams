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
import std.regex;
import std.algorithm;

const double MIN_COVERAGE_PERCENT = 0.95;

const FILE_IGNORE_PATTERNS = [
    `_test_root`,
];

const LINE_IGNORE_PATTERNS = [
    `cov-ignore$`
];

int main() {
    if (!exists("coverage")) mkdir("coverage");

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
        bool shouldSkipFile = false;
        foreach (pattern; FILE_IGNORE_PATTERNS) {
            auto r = regex(pattern);
            if (matchFirst(entry.name, r)) {
                shouldSkipFile = true;
                break;
            }
        }
        if (shouldSkipFile) continue;

        LSTFile file = LSTFile(entry);
        fileCount++;

        writeln(file.filename);
        bool coveredCompletely = true;
        foreach (idx, line; file.lines) {
            if (!line.coverage.isNull) {
                bool shouldSkipLine = false;
                foreach (pattern; LINE_IGNORE_PATTERNS) {
                    auto r = regex(pattern);
                    if (matchFirst(line.content, r)) {
                        shouldSkipLine = true;
                        break;
                    }
                }
                if (shouldSkipLine) continue;
                uint coverage = line.coverage.get();
                if (coverage > 0) {
                    coveredLineCount++;
                } else {
                    writefln!"  ! L%04d -> %s"(idx, line.content);
                    coveredCompletely = false;
                }
                lineCount++;
            }
        }
        if (coveredCompletely) {
            writeln("  100% Covered!");
        }
    }
    double coverageAvg = cast(double) coveredLineCount / lineCount;
    writefln!"Total coverage of %.2f%% (%d/%d) lines in %d files."(
        coverageAvg * 100, coveredLineCount, lineCount, fileCount
    );
    if (coverageAvg < MIN_COVERAGE_PERCENT) {
        stderr.writefln!"Coverage is less than the required %.2f%%."(MIN_COVERAGE_PERCENT * 100);
        return 1;
    }
    return 0;
}
