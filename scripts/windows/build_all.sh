#!/bin/sh

set -e

./build_openssl.sh
./build_secp256k1.sh
./prep_sharedfile.sh
