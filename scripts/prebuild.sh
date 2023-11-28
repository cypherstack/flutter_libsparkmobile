#!/usr/bin/env bash

set -e

cd ../src/deps

if [ -d sparkmobile ]; then
  rm -rf sparkmobile
fi

git clone https://github.com/firoorg/sparkmobile.git
cd sparkmobile
git checkout ef2e39aae18ecc49e0ddc63a3183e9764b96012e

cd ..
cp CMakeLists/sparkmobile/CMakeLists.txt     sparkmobile/
cp CMakeLists/secp256k1/CMakeLists.txt       sparkmobile/secp256k1/