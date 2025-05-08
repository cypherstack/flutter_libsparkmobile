#!/usr/bin/env bash

set -e

cd ..
git submodule update --init --recursive

cp src/deps/CMakeLists/sparkmobile/CMakeLists.txt     src/deps/sparkmobile/
cp src/deps/CMakeLists/secp256k1/CMakeLists.txt       src/deps/sparkmobile/secp256k1/


pushd src/deps/boost-cmake
  if git apply -q --check ../patches/boost-patch.patch; then
    git apply ../patches/boost-patch.patch
  fi
popd

pushd src/deps/openssl-cmake
  if git apply -q --check ../patches/openssl-cmake-patch.patch; then
    git apply ../patches/openssl-cmake-patch.patch
  fi
popd
