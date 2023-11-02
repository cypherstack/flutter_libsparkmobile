#!/bin/bash

WORKDIR="$(pwd)/build"
SEDWORKDIR=$(echo $WORKDIR | sed 's/\//\\\//g')

# Create new CMakelists.txt files for the sparkmobile and secp256k1 directories.
#
# Copy the template CMakelists.txt files to the working sparkmobile directory and replace the
# distribution_DIR variable with the working directory.
sed "s/SET(distribution_DIR \/opt\/android)/SET(distribution_DIR $SEDWORKDIR)/g" ./CMakeLists/sparkmobile/template_CMakeLists.txt > ./CMakeLists/sparkmobile/CMakeLists.txt
sed "s/SET(distribution_DIR \/opt\/android)/SET(distribution_DIR $SEDWORKDIR)/g" ./CMakeLists/secp256k1/template_CMakeLists.txt > ./CMakeLists/secp256k1/CMakeLists.txt
