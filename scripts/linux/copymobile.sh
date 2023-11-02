#!/bin/bash

# Copy the sparkmobile submodule to the build directory for interfacing to Dart.
#
# We copy the fresh and unmodified sparkmobile submodule to the build directory in order to graft
# an additional Dart interface onto the sparkmobile library.
cp -r ../../sparkmobile .
