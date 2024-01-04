#!/usr/bin/env bash

set -e

export MACOS_SCRIPTS_DIR=`pwd`
export PROJECT_ROOT_DIR="${MACOS_SCRIPTS_DIR}/../.."

if [ ! -d build ] ; then
  mkdir build
fi
cd build
cmake ../../../src -DBUILD_FOR_SYSTEM_NAME="macos" && make -j12
cp -R flutter_libsparkmobile.framework "${PROJECT_ROOT_DIR}/macos/"
