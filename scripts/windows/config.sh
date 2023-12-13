#!/bin/sh

export SCRIPTDIR="$(pwd)/"
export WORKDIR="$(pwd)/"build
export CACHEDIR="$(pwd)/"cache
export SEDWORKDIR=$(echo $WORKDIR | sed 's/\//\\\//g')

mkdir -p $WORKDIR
mkdir -p $CACHEDIR
