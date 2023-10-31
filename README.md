# `flutter_libsparkmobile`
[SparkMobile](https://github.com/firoorg/sparkmobile) wrapped as a Flutter plugin for cross-platform mobile and desktop apps.  Intended to support Android, iOS, Linux, Mac, and Windows platforms.

## Dependencies
Install dependencies required to build:
```sh
sudo apt install libboost-thread-dev
```

## Build
Build:
```sh
cd flutter_libsparkmobile/scripts/linux
./build_all.sh
```

## Development
If you need to test changes in sparkmobile itself, you may need to install Boost development libraries as in `sudo apt install libboost-all-dev`.

Get vectors like `./test bin && ./bin/address_tests`.
