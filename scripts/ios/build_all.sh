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

# Build for iOS device (arm64)
cmake ../../../src \
  -G Xcode \
  -DPLATFORM=OS64 \
  -DBUILD_FOR_SYSTEM_NAME="ios" \
  -DCMAKE_TOOLCHAIN_FILE=${IOS_TOOLCHAIN_ROOT}/ios.toolchain.cmake \
  -DCMAKE_CXX_FLAGS="--std=c++17 -D_LIBCPP_ENABLE_CXX17_REMOVED_FEATURES" \
  -B build-device
cmake --build build-device --config Debug
cmake --install build-device --config Debug

# Build for iOS simulator (arm64 only, no x86_64)
cmake ../../../src \
  -G Xcode \
  -DPLATFORM=SIMULATORARM64 \
  -DBUILD_FOR_SYSTEM_NAME="ios" \
  -DCMAKE_TOOLCHAIN_FILE=${IOS_TOOLCHAIN_ROOT}/ios.toolchain.cmake \
  -DCMAKE_CXX_FLAGS="--std=c++17 -D_LIBCPP_ENABLE_CXX17_REMOVED_FEATURES" \
  -B build-simulator
cmake --build build-simulator --config Debug
cmake --install build-simulator --config Debug

# Update Info.plist files before creating XCFramework
plutil -replace CFBundleShortVersionString -string "0.0.1" build-device/Debug-iphoneos/flutter_libsparkmobile.framework/Info.plist
plutil -replace CFBundleVersion -string "1" build-device/Debug-iphoneos/flutter_libsparkmobile.framework/Info.plist
plutil -replace CFBundleShortVersionString -string "0.0.1" build-simulator/Debug-iphonesimulator/flutter_libsparkmobile.framework/Info.plist
plutil -replace CFBundleVersion -string "1" build-simulator/Debug-iphonesimulator/flutter_libsparkmobile.framework/Info.plist

# Remove old XCFramework if it exists
rm -rf flutter_libsparkmobile.xcframework

# Create XCFramework to support both device and simulator (same architecture, different platforms)
# XCFramework can contain multiple frameworks with the same architecture but different platforms
xcodebuild -create-xcframework \
  -framework build-device/Debug-iphoneos/flutter_libsparkmobile.framework \
  -framework build-simulator/Debug-iphonesimulator/flutter_libsparkmobile.framework \
  -output flutter_libsparkmobile.xcframework

# Verify XCFramework was created successfully
if [ ! -d "flutter_libsparkmobile.xcframework" ]; then
  echo "Error: XCFramework creation failed!"
  exit 1
fi

# Remove old framework if it exists (to avoid confusion)
rm -rf "${PROJECT_ROOT_DIR}/ios/flutter_libsparkmobile.framework"
rm -rf "${PROJECT_ROOT_DIR}/ios/flutter_libsparkmobile.xcframework"

# Copy XCFramework to ios directory
cp -R flutter_libsparkmobile.xcframework "${PROJECT_ROOT_DIR}/ios/"

echo "XCFramework created successfully at ${PROJECT_ROOT_DIR}/ios/flutter_libsparkmobile.xcframework"
