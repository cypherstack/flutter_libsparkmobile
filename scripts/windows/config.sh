#!/bin/sh

export SCRIPTDIR="$(pwd)/"
export WORKDIR="$(pwd)"/../../build/windows
export CACHEDIR="$(pwd)"/../../build/cache
export SEDWORKDIR=$(echo $WORKDIR | sed 's/\//\\\//g')

mkdir -p $WORKDIR
mkdir -p $CACHEDIR
