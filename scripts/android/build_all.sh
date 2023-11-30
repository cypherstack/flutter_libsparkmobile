#!/bin/bash

set -e

WORKDIR="$(pwd)/../../src/build/android"
export WORKDIR
export API=21
export ANDROID_NDK_ZIP=${WORKDIR}/android-ndk-r20b.zip
export ANDROID_NDK_ROOT=${WORKDIR}/android-ndk-r20b
export ANDROID_NDK_HOME=$ANDROID_NDK_ROOT
export TOOLCHAIN_DIR="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"

case :${PATH:=${TOOLCHAIN_DIR}/bin}: in
(*:"${TOOLCHAIN_DIR}/bin":*) ;; (*)
    export PATH=${TOOLCHAIN_DIR}/bin:$PATH
esac;

if [ ! -d "$WORKDIR" ] ; then
  mkdir -p "$WORKDIR"
fi

# NDK
ANDROID_NDK_SHA256="8381c440fe61fcbb01e209211ac01b519cd6adf51ab1c2281d5daad6ca4c8c8c"

if [ ! -e "$ANDROID_NDK_ZIP" ]; then
  curl https://dl.google.com/android/repository/android-ndk-r20b-linux-x86_64.zip -o "${ANDROID_NDK_ZIP}"
fi
echo $ANDROID_NDK_SHA256 "$ANDROID_NDK_ZIP" | sha256sum -c || exit 1
unzip "$ANDROID_NDK_ZIP" -d "$WORKDIR"


# openssl
OPENSSL_FILENAME="openssl-1.1.1q.tar.gz"
OPENSSL_FILE_PATH="$WORKDIR/$OPENSSL_FILENAME"
OPENSSL_SRC_DIR="$WORKDIR/openssl-1.1.1q"
OPENSSL_SHA256="d7939ce614029cdff0b6c20f0e2e5703158a489a72b2507b8bd51bf8c8fd10ca"

if [ ! -e "$OPENSSL_FILE_PATH" ]; then
  curl https://www.openssl.org/source/$OPENSSL_FILENAME -o "$OPENSSL_FILE_PATH"
fi

echo $OPENSSL_SHA256 "$OPENSSL_FILE_PATH" | sha256sum -c - || exit 1

for arch in "aarch" "aarch64" "i686" "x86_64"
do

case $arch in
	"aarch")   CLANG=armv7a-linux-androideabi${API}-clang
		   CXXLANG=armv7a-linux-androideabi${API}-clang++
       PREFIX="$WORKDIR/prefix_armeabi-v7a"
		   X_ARCH="android-arm";;
	"aarch64") CLANG=${arch}-linux-android${API}-clang
		   CXXLANG=${arch}-linux-android${API}-clang++
       PREFIX="$WORKDIR/prefix_arm64-v8a"
		   X_ARCH="android-arm64";;
	"i686")    CLANG=${arch}-linux-android${API}-clang
		   CXXLANG=${arch}-linux-android${API}-clang++
       PREFIX="$WORKDIR/prefix_x86"
		   X_ARCH="android-x86";;
	"x86_64")  CLANG=${arch}-linux-android${API}-clang
		   CXXLANG=${arch}-linux-android${API}-clang++
       PREFIX="$WORKDIR/prefix_x86_64"
		   X_ARCH="android-x86_64";;
	*)	   CLANG=${arch}-linux-android${API}-clang
		   CXXLANG=${arch}-linux-android${API}-clang++
       PREFIX="$WORKDIR/prefix_${arch}"
		   X_ARCH="android-${arch}";;
esac

cd "$WORKDIR"
rm -rf "$OPENSSL_SRC_DIR"
tar -xzf "$OPENSSL_FILE_PATH" -C "$WORKDIR"
cd "$OPENSSL_SRC_DIR"
./Configure CC=${CLANG} CXX=${CXXLANG} ${X_ARCH} \
	no-asm no-shared no-tests --static \
	--prefix="${PREFIX}" \
	--openssldir="${PREFIX}" \
	-D__ANDROID_API__=$API
sed -i 's/CNF_EX_LIBS=-ldl -pthread//g;s/BIN_CFLAGS=-pie $(CNF_CFLAGS) $(CFLAGS)//g' Makefile
make -j16
make install_sw

done




