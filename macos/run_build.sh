#!/usr/bin/env bash
set -e
cd ../scripts
./prebuild.sh
cd macos
./build_all.sh
