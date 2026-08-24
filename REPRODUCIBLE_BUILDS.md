# Reproducible native builds

The Nix build produces the Linux `libflutter_libsparkmobile.so` from the
vendored SparkMobile, secp256k1, and OpenSSL sources. Boost 1.71 is supplied as
a content-addressed flake input, so CMake does not download it during the
build. `flake.lock` pins Boost and the complete compiler environment.

```sh
nix build .#flutter-libsparkmobile
./nix/verify-reproducible.sh
```

The release build removes debug paths, disables the ELF build ID, and sets a
fixed `SOURCE_DATE_EPOCH`. Verification rebuilds the same Nix derivation and
fails if the result differs.

Only Linux is covered here. Android, Windows, and Apple SDK inputs still need
separate pinned cross-compilation derivations.
