# `flutter_libsparkmobile`
[SparkMobile](https://github.com/firoorg/sparkmobile) wrapped as a Flutter plugin for cross-platform mobile and desktop apps.  Intended to support Android, iOS, Linux, Mac, and Windows platforms.

## Initialize `sparkmobile` submodule
```sh
git submodule update --init --recursive
```

## Dependencies
Install dependencies required to build:
```sh
sudo apt install libboost-thread-dev
```

## Build
Build the native library for your platform like:
```sh
cd flutter_libsparkmobile/scripts/linux
./build_all.sh
```

## Example
See the [example](example) directory for a Flutter app that uses `flutter_libsparkmobile`.

You must have the native library built for your platform before running the example app.  See the [Build](#build) section above.

## Development
### Bindings generation (`dart run ffigen`)
Bindings are generated using [ffigen](https://pub.dev/packages/ffigen).  All of the individual build scripts in your platform's `build_all.sh` script must be run up to and including `copyCMakeLists.sh` in order for the header referenced in `pubspec.yaml`'s `ffigen` section to exist.

### `sparkmobile` troubleshooting
If you need to test changes in `sparkmobile` itself, you may need to install Boost development libraries as in `sudo apt install libboost-all-dev`.

Get vectors like `./test bin && ./bin/address_tests`.
