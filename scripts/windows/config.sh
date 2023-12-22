#!/bin/sh

export SCRIPTDIR="$(pwd)/"
export WORKDIR="$(pwd)"/../../src/build/windows
export CACHEDIR="$(pwd)"/../../src/cache
export SEDWORKDIR=$(echo $WORKDIR | sed 's/\//\\\//g')

mkdir -p $WORKDIR
mkdir -p $CACHEDIR
