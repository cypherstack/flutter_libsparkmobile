# `flutter_libsparkmobile`
[SparkMobile](https://github.com/firoorg/sparkmobile) wrapped as a Flutter plugin for cross-platform mobile and desktop apps.  Intended to support Android, iOS, Linux, Mac, and Windows platforms.

## Build

1. Initialize submodules and setup.
```sh
cd flutter_libsparkmobile/scripts
./prebuild.sh
```

Windows builds natively, so skip Step 2 on Windows.

2. Build the native library deps for your platform like:
```sh
cd flutter_libsparkmobile/scripts/linux
./build_all.sh
```

3. Finish the build with Flutter:
```
cd flutter_libsparkmobile
flutter build
```

## Example
See the [example](example) directory for a Flutter app that uses `flutter_libsparkmobile`.

You must have the native library built for your platform before running the example app.  See the [Build](#build) section above.

### Integration tests
`example/test/integration_test.dart` tests various vectors for correctness.  Run it from `example` as in `flutter test integration_test/plugin_integration_test.dart`.

## Development
### Bindings generation (`dart run ffigen --config ffigen.yaml`)
Bindings are generated using [ffigen](https://pub.dev/packages/ffigen).  After bindings are generated, wrap the bound functions in `flutter_libsparkmobile.dart`.

### `sparkmobile` troubleshooting
If you need to test changes in `sparkmobile` itself, you may need to install Boost development libraries as in `sudo apt install libboost-all-dev`.

Run integration tests like `./interface bin && ./bin/interface_test`.
