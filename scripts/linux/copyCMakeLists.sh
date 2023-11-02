#!/bin/bash

# Copy the Dart interface, utilities, and CMakeLists.txt to the sparkmobile directory.
#
# This grafts an additional Dart interface onto the sparkmobile library.
cp CMakeLists/sparkmobile/dart_interface.cpp sparkmobile/src/
cp CMakeLists/sparkmobile/dart_interface.h   sparkmobile/src/
cp CMakeLists/sparkmobile/utils.cpp          sparkmobile/src/
cp CMakeLists/sparkmobile/utils.h            sparkmobile/src/
cp CMakeLists/sparkmobile/CMakeLists.txt     sparkmobile/
cp CMakeLists/secp256k1/CMakeLists.txt       sparkmobile/secp256k1/
