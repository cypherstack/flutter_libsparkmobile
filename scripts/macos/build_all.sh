#!/usr/bin/env bash

set -e

export MACOS_SCRIPTS_DIR=`pwd`
export PROJECT_ROOT_DIR="${MACOS_SCRIPTS_DIR}/../.."
export MOBILE_LIB_ROOT="${PROJECT_ROOT_DIR}/src"
export EXTERNAL_MACOS_DIR="${MOBILE_LIB_ROOT}/build/macos"
export EXTERNAL_MACOS_SOURCE_DIR=${EXTERNAL_MACOS_DIR}/sources
export EXTERNAL_MACOS_LIB_DIR=${EXTERNAL_MACOS_DIR}/lib
export EXTERNAL_MACOS_INCLUDE_DIR=${EXTERNAL_MACOS_DIR}/include

mkdir -p $EXTERNAL_MACOS_DIR
mkdir -p $EXTERNAL_MACOS_LIB_DIR
mkdir -p $EXTERNAL_MACOS_INCLUDE_DIR
mkdir -p $EXTERNAL_MACOS_SOURCE_DIR

./build_openssl_arm64.sh

if [ ! -d build ] ; then
  mkdir build
fi
cd build
cmake ../../../src -DBUILD_FOR_SYSTEM_NAME="macos" && make -j12
cp -R flutter_libsparkmobile.framework "${PROJECT_ROOT_DIR}/macos/"
