. ./config.sh

cd $SCRIPTDIR

mkdir -p "$WORKDIR/include"
mkdir -p "$WORKDIR/sparkmobile"
mkdir -p "$WORKDIR/sparkmobile/include"
cp -r ../../src/deps/sparkmobile/* "$WORKDIR/sparkmobile"

# echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> build/git_commit_version.txt
# VERSIONS_FILE=../../lib/git_versions.dart
# EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
# if [ ! -f "$VERSIONS_FILE" ]; then
#     cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
# fi
# COMMIT=$(git log -1 --pretty=format:"%H")
# OS="WINDOWS"
# sed -i "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE

cd $WORKDIR/sparkmobile
rm -f CMakeCache.txt
x86_64-w64-mingw32.static-cmake . \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DBUILD_FOR_SYSTEM_NAME="windows"
make -j$(nproc)
