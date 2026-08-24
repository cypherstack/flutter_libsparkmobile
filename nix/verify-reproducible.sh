#!/usr/bin/env bash
set -euo pipefail

flake_ref="${1:-.#flutter-libsparkmobile}"

nix build "$flake_ref" --no-link
nix build "$flake_ref" --no-link --rebuild

output_path="$(nix path-info "$flake_ref")"
sha256sum "$output_path/lib/libflutter_libsparkmobile.so"
