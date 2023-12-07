#!/bin/bash

# Build test in "bin" folder by default, or accept a parameter $1.
dir_name=${1:-bin}

if [ -f $dir_name ]; then
  echo "File $dir_name exists"
  exit
fi

# Build secp256k1.
cd "deps/sparkmobile/secp256k1" && ./autogen.sh
./configure --enable-experimental --enable-module-ecdh --with-bignum=no --enable-endomorphism
make -j4
cd ../../..
mkdir -p $dir_name

# Build.
echo "Building debugging test"
g++ interface_test.cpp deps/sparkmobile/src/*.cpp deps/sparkmobile/bitcoin/*.cpp deps/sparkmobile/bitcoin/support/*.cpp deps/sparkmobile/bitcoin/crypto/*.cpp -g -Isecp256k1/include deps/sparkmobile/secp256k1/.libs/libsecp256k1.a  -lssl -lcrypto -lpthread -lboost_unit_test_framework -std=c++17 -o $dir_name/interface_test

# Run test.
echo Running interface test
./$dir_name/interface_test
