#!/usr/bin/env bash

set -e

export IOS_SCRIPTS_DIR=`pwd`
export PROJECT_ROOT_DIR="${IOS_SCRIPTS_DIR}/../.."
export IOS_SCRIPTS_BUILD_DIR="${IOS_SCRIPTS_DIR}/build"
export IOS_TOOLCHAIN_ROOT="${IOS_SCRIPTS_BUILD_DIR}/toolchain"

mkdir -p "${IOS_SCRIPTS_BUILD_DIR}"
cd "${IOS_SCRIPTS_BUILD_DIR}"

TOOLCHAIN_URL="https://github.com/leetal/ios-cmake.git"
TOOLCHAIN_DIR_PATH="${IOS_TOOLCHAIN_ROOT}"

if [ ! -d "$TOOLCHAIN_DIR_PATH" ] ; then
  git clone $TOOLCHAIN_URL $TOOLCHAIN_DIR_PATH
fi

cmake ../../../src \
  -G Xcode \
  -DPLATFORM=OS64COMBINED \
-DBUILD_FOR_SYSTEM_NAME="ios" \
-DCMAKE_TOOLCHAIN_FILE=${IOS_TOOLCHAIN_ROOT}/ios.toolchain.cmake \
-DCMAKE_CXX_FLAGS="--std=c++17 -D_LIBCPP_ENABLE_CXX17_REMOVED_FEATURES"
cmake --build . --config Debug
cmake --install . --config Debug
cd Debug-iphoneos

plutil -replace CFBundleShortVersionString -string "0.0.1" ./flutter_libsparkmobile.framework/Info.plist
plutil -replace CFBundleVersion -string "1" ./flutter_libsparkmobile.framework/Info.plist
cp -R flutter_libsparkmobile.framework "${PROJECT_ROOT_DIR}/ios/"
