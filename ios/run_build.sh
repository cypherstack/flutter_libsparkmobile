#!/usr/bin/env bash
set -e
cd ../scripts
./prebuild.sh
cd ios
./build_all.sh
