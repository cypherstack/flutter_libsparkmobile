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
OPENSSL_FILENAME="openssl-1.1.1k.tar.gz"
OPENSSL_FILE_PATH="$WORKDIR/$OPENSSL_FILENAME"
OPENSSL_SRC_DIR="$WORKDIR/openssl-1.1.1k"
OPENSSL_SHA256="892a0875b9872acd04a9fde79b1f943075d5ea162415de3047c327df33fbaee5"
ZLIB_DIR="$WORKDIR/zlib"
ZLIB_TAG="v1.2.11"
ZLIB_COMMIT_HASH="cacf7f1d4e3d44d871b605da3b647f07d718623f"


if [ ! -d "$ZLIB_DIR" ] ; then
  git clone -b $ZLIB_TAG --depth 1 https://github.com/madler/zlib "$ZLIB_DIR"
fi
cd "$ZLIB_DIR"
git reset --hard $ZLIB_COMMIT_HASH
CC=clang CXX=clang++ ./configure --static
make

if [ ! -e "$OPENSSL_FILE_PATH" ]; then
  curl https://www.openssl.org/source/$OPENSSL_FILENAME -o "$OPENSSL_FILE_PATH"
fi

echo $OPENSSL_SHA256 "$OPENSSL_FILE_PATH" | sha256sum -c - || exit 1

for arch in "aarch" "aarch64" "i686" "x86_64"
do
PREFIX=$WORKDIR/prefix_${arch}

case $arch in
	"aarch")   CLANG=armv7a-linux-androideabi${API}-clang
		   CXXLANG=armv7a-linux-androideabi${API}-clang++
		   X_ARCH="android-arm";;
	"aarch64") CLANG=${arch}-linux-android${API}-clang
		   CXXLANG=${arch}-linux-android${API}-clang++
		   X_ARCH="android-arm64";;
	"i686")    CLANG=${arch}-linux-android${API}-clang
		   CXXLANG=${arch}-linux-android${API}-clang++
		   X_ARCH="android-x86";;
	"x86_64")  CLANG=${arch}-linux-android${API}-clang
		   CXXLANG=${arch}-linux-android${API}-clang++
		   X_ARCH="android-x86_64";;
	*)	   CLANG=${arch}-linux-android${API}-clang
		   CXXLANG=${arch}-linux-android${API}-clang++
		   X_ARCH="android-${arch}";;
esac

cd "$WORKDIR"
rm -rf "$OPENSSL_SRC_DIR"
tar -xzf "$OPENSSL_FILE_PATH" -C "$WORKDIR"
cd "$OPENSSL_SRC_DIR"
./Configure CC=${CLANG} CXX=${CXXLANG} ${X_ARCH} \
	no-asm no-shared no-tests --static \
	--with-zlib-include="${PREFIX}"/include \
	--with-zlib-lib="${PREFIX}"/lib \
	--prefix="${PREFIX}" \
	--openssldir="${PREFIX}" \
	-D__ANDROID_API__=$API
sed -i 's/CNF_EX_LIBS=-ldl -pthread//g;s/BIN_CFLAGS=-pie $(CNF_CFLAGS) $(CFLAGS)//g' Makefile
make -j16
make install_sw

done




