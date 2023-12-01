#!/usr/bin/env bash

set -e

export IOS_SCRIPTS_DIR=`pwd`
export PROJECT_ROOT_DIR="${IOS_SCRIPTS_DIR}/../.."
export PROJECT_SRC_DIR="${PROJECT_ROOT_DIR}/src"
export EXTERNAL_IOS_DIR="${PROJECT_SRC_DIR}/build/ios"
export IOS_TOOLCHAIN_ROOT="${EXTERNAL_IOS_DIR}/toolchain"
export EXTERNAL_IOS_SOURCE_DIR=${EXTERNAL_IOS_DIR}/sources
export EXTERNAL_IOS_LIB_DIR=${EXTERNAL_IOS_DIR}/lib
export EXTERNAL_IOS_INCLUDE_DIR=${EXTERNAL_IOS_DIR}/include

mkdir -p $EXTERNAL_IOS_LIB_DIR
mkdir -p $EXTERNAL_IOS_INCLUDE_DIR
mkdir -p $EXTERNAL_IOS_SOURCE_DIR

OPEN_SSL_URL="https://github.com/x2on/OpenSSL-for-iPhone.git"
OPEN_SSL_DIR_PATH="${EXTERNAL_IOS_SOURCE_DIR}/OpenSSL"

echo "============================ OpenSSL ============================"

if [ ! -d "$OPEN_SSL_DIR_PATH" ] ; then
  echo "Cloning Open SSL from - $OPEN_SSL_URL"
  git clone "$OPEN_SSL_URL" "$OPEN_SSL_DIR_PATH"

  cd "$OPEN_SSL_DIR_PATH" || exit 1
  git checkout b77ace70b2594de69c88d0748326d2a1190bbac1
  sed -i '' "s/IOS_MIN_SDK_VERSION=\"12.0\"/IOS_MIN_SDK_VERSION=\"10.0\"/g" build-libssl.sh

else
  cd "$OPEN_SSL_DIR_PATH" || exit 1
fi


#./build-libssl.sh --version=1.1.1k --archs="arm64" --targets="ios64-cross-arm64" --deprecated
./build-libssl.sh \
--version=1.1.1k \
--archs="x86_64 arm64 armv7s armv7" \
--targets="ios-sim-cross-x86_64 ios64-cross-arm64 ios-cross-armv7 ios-cross-armv7s" \
--deprecated

cp -R "${OPEN_SSL_DIR_PATH}"/include/* "${EXTERNAL_IOS_INCLUDE_DIR}/"
cp -R "${OPEN_SSL_DIR_PATH}"/lib/* "${EXTERNAL_IOS_LIB_DIR}/"


#TOOLCHAIN_URL="https://github.com/cristeab/ios-cmake.git"
TOOLCHAIN_URL="https://github.com/leetal/ios-cmake.git"
TOOLCHAIN_DIR_PATH="${IOS_TOOLCHAIN_ROOT}"

if [ ! -d "$TOOLCHAIN_DIR_PATH" ] ; then
  git clone $TOOLCHAIN_URL $TOOLCHAIN_DIR_PATH
fi

cd "${IOS_SCRIPTS_DIR}"

if [ ! -d build ] ; then
  mkdir build
fi

cd build

#cmake ../../../src --trace \
# -DCMAKE_TOOLCHAIN_FILE="${IOS_TOOLCHAIN_ROOT}/toolchain/iOS.cmake" \
# -DBUILD_FOR_SYSTEM_NAME="ios" && make -j12

cmake ../../../src \
  -G Xcode \
  -DPLATFORM=OS64COMBINED \
-DBUILD_FOR_SYSTEM_NAME="ios" \
-DCMAKE_TOOLCHAIN_FILE=${IOS_TOOLCHAIN_ROOT}/ios.toolchain.cmake
cmake --build . --config Debug
cmake --install . --config Debug
cd Debug-iphoneos

#cmake ../../../src \
#  -G Xcode \
#  -DPLATFORM=SIMULATOR64 \
#-DBUILD_FOR_SYSTEM_NAME="ios" \
#-DCMAKE_TOOLCHAIN_FILE=${IOS_TOOLCHAIN_ROOT}/ios.toolchain.cmake
#cmake --build . --config Debug
#cmake --install . --config Debug
#cd Debug-iphonesimulator

#cmake ../../../src \
#  -G Xcode \
#  -DPLATFORM=SIMULATOR64 \
#-DBUILD_FOR_SYSTEM_NAME="ios" \
#-DCMAKE_TOOLCHAIN_FILE=${IOS_TOOLCHAIN_ROOT}/ios.toolchain.cmake
#cmake --build . --config Release
#cmake --install . --config Release
#cd Release-iphonesimulator

# -DENABLE_STRICT_TRY_COMPILE=ON \


#sed -i '' "s/<dict>/<dict>\n\t<key>MinimumOSVersion<\/key>\n\t<string>11.0<\/string>/g" flutter_libsparkmobile.framework/Info.plist
cp -R flutter_libsparkmobile.framework "${PROJECT_ROOT_DIR}/ios/"

#cmake ../../../src \
#-DBUILD_FOR_SYSTEM_NAME="ios" \
# -DENABLE_STRICT_TRY_COMPILE=ON \
#-DCMAKE_TOOLCHAIN_FILE=${IOS_TOOLCHAIN_ROOT}/ios.toolchain.cmake \
#-DPLATFORM=SIMULATOR64
#make -j12
#
#sed -i '' "s/<dict>/<dict>\n\t<key>MinimumOSVersion<\/key>\n\t<string>11.0<\/string>/g" ./flutter_libsparkmobile.framework/Info.plist
#cp -R flutter_libsparkmobile.framework "${PROJECT_ROOT_DIR}/ios/"
