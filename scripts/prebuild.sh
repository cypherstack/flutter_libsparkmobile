#!/usr/bin/env bash

set -e

cd ..
git submodule update --init --recursive

cp src/deps/CMakeLists/sparkmobile/CMakeLists.txt     src/deps/sparkmobile/
cp src/deps/CMakeLists/secp256k1/CMakeLists.txt       src/deps/sparkmobile/secp256k1/


pushd src/deps/boost-cmake
  git apply ../patches/boost-patch.patch || true
popd