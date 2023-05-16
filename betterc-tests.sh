#!/usr/bin/env bash

dmd -betterC -unittest -debug source/streams/primitives.d \
    source/streams/package.d \
    source/streams/functions.d \
    source/streams/interfaces.d \
    source/streams/utils.d \
    source/streams/range.d \
    source/streams/types/package.d \
    source/streams/types/array.d \
    source/streams/types/data.d \
    source/streams/types/file.d \
    source/streams/types/socket.d \
    source/streams/types/buffered.d \

./primitives
