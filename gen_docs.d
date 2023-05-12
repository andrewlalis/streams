#!/usr/bin/env rdmd
module gen_docs;

import std.process;
import std.stdio;
import std.file;
import std.path;

const DOCS_DIR = "generated-docs";

int main() {
    const mainDir = getcwd();
    if (!exists(DOCS_DIR)) mkdir(DOCS_DIR);

    if (!exists("adrdox")) {
        writeln("Cloning adrdox...");
        auto result = executeShell("git clone git@github.com:adamdruppe/adrdox.git");
        if (result.status != 0) {
            stderr.writefln!"Failed to clone adrdox: %d"(result.status);
            return result.status;
        }
        chdir("adrdox");
        writeln("Building adrdox...");
        result = executeShell("make");
        if (result.status != 0) {
            stderr.writefln!"Failed to build adrdox: %d"(result.status);
            return result.status;
        }
        chdir(mainDir);
    }

    writeln("Generating docs...");
    auto result = executeShell("adrdox/doc2 -o generated-docs -p --document-undocumented source/streams");
    writefln!"Exited with code %d"(result.status);
    return result.status;
}