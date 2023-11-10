#!/bin/bash

# Copy the sparkmobile submodule to the build directory for interfacing to Dart.
#
# We copy the fresh and unmodified sparkmobile submodule to the build directory in order to graft
# an additional Dart interface onto the sparkmobile library.
cp -r ../../sparkmobile .

WORKDIR="$(pwd)/build"
SEDWORKDIR=$(echo $WORKDIR | sed 's/\//\\\//g')

# Create new CMakelists.txt files for the sparkmobile and secp256k1 directories.
#
# Copy the template CMakelists.txt files to the working sparkmobile directory and replace the
# distribution_DIR variable with the working directory.
sed "s/SET(distribution_DIR \/opt\/android)/SET(distribution_DIR $SEDWORKDIR)/g" ./CMakeLists/sparkmobile/template_CMakeLists.txt > ./CMakeLists/sparkmobile/CMakeLists.txt
sed "s/SET(distribution_DIR \/opt\/android)/SET(distribution_DIR $SEDWORKDIR)/g" ./CMakeLists/secp256k1/template_CMakeLists.txt > ./CMakeLists/secp256k1/CMakeLists.txt

# Copy the sparkmobile and secp256k1 CMakeLists.txts.
cp CMakeLists/sparkmobile/CMakeLists.txt     sparkmobile/
cp CMakeLists/secp256k1/CMakeLists.txt       sparkmobile/secp256k1/

# Git versioning.
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> build/git_commit_version.txt
VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="LINUX"

# Write the commit hash to the versions file.
sed -i "/\/\*${OS}_VERSION/c\\/\*${OS}_VERSION\*\/ const ${OS}_VERSION = \"$COMMIT\";" $VERSIONS_FILE

# Build the shared library.
cd build
cmake ../sparkmobile
make -j$(nproc)
