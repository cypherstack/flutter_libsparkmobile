#!/bin/sh

set -e

export WORKDIR="$(pwd)/../../src/build/linux"
export ORIGINAL_PATH=$PATH
export THREADS=16
export TYPES_OF_BUILD="x86_64"

if [ -z "$IS_ARM" ]; then
  export TYPES_OF_BUILD="x86_64"
else
  export TYPES_OF_BUILD="aarch64"
fi

if [ ! -d "$WORKDIR" ] ; then
  mkdir -p "$WORKDIR"
fi


OPENSSL_FILENAME="openssl-1.1.1k.tar.gz"
OPENSSL_FILE_PATH="$WORKDIR/$OPENSSL_FILENAME"
OPENSSL_SRC_DIR="$WORKDIR/openssl-1.1.1k"
OPENSSL_SHA256="892a0875b9872acd04a9fde79b1f943075d5ea162415de3047c327df33fbaee5"
ZLIB_DIR="$WORKDIR/zlib"
ZLIB_TAG="v1.2.11"
ZLIB_COMMIT_HASH="cacf7f1d4e3d44d871b605da3b647f07d718623f"


if [ ! -d "$ZLIB_DIR" ] ; then
  git clone -b $ZLIB_TAG --depth 1 https://github.com/madler/zlib $ZLIB_DIR
fi
cd $ZLIB_DIR
git reset --hard $ZLIB_COMMIT_HASH
./configure --static
make

curl https://www.openssl.org/source/$OPENSSL_FILENAME -o $OPENSSL_FILE_PATH
echo $OPENSSL_SHA256 $OPENSSL_FILE_PATH | sha256sum -c - || exit 1

for arch in $TYPES_OF_BUILD
do
echo "Building $TYPES_OF_BUILD"
PREFIX=$WORKDIR/prefix_${arch}

case $arch in
	"x86_64")  X_ARCH="linux-x86_64";;
	"aarch64")  X_ARCH="linux-aarch64";;
	*)	   X_ARCH="linux-x86_64";;
esac

cd $WORKDIR
rm -rf $OPENSSL_SRC_DIR
tar -xzf $OPENSSL_FILE_PATH -C $WORKDIR
cd $OPENSSL_SRC_DIR

./Configure ${X_ARCH} \
	no-asm no-shared \
	--with-zlib-include=${PREFIX}/include \
	--with-zlib-lib=${PREFIX}/lib \
	--prefix=${PREFIX} \
	--openssldir=${PREFIX}
make -j$THREADS
make -j$THREADS install_sw

done

