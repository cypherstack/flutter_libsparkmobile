. ./config.sh

cd $SCRIPTDIR

mkdir -p "$WORKDIR/include"
mkdir -p "$WORKDIR/secp256k1"
mkdir -p "$WORKDIR/secp256k1/include"
cp -r ../../src/deps/sparkmobile/secp256k1/* "$WORKDIR/secp256k1"

cp $SCRIPTDIR/missingheader/endian.h	$WORKDIR/secp256k1/include/endian.h

cd $WORKDIR/secp256k1
rm -f CMakeCache.txt
x86_64-w64-mingw32.static-cmake . \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_INSTALL_PREFIX="${WORKDIR}"
make -j$(nproc)
# make -j$(nproc) all install # Doesn't respect our CMAKE_INSTALL_PREFIX passed above, so we'll just copy it manually.
cp libsecp256k1_spark.a ../lib/
