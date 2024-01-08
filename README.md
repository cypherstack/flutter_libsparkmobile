# `flutter_libsparkmobile`
[SparkMobile](https://github.com/firoorg/sparkmobile) wrapped as a Flutter plugin for cross-platform mobile and desktop apps.  Supports Android, iOS, Linux, Mac, and Windows platforms.

## Build

Use `flutter build` to build or `flutter run` the example app.

Note that the example app requires Coinlib's `secp256k1` lib to be built (use `dart run coinlib:build_linux` for Linux, `dart run coinlib:build_windows` for Windows, etc.).

## Example
See the [example](example) directory for a Flutter app that uses `flutter_libsparkmobile`.

### Integration tests
`example/test/integration_test.dart` tests various vectors for correctness.  Run it from `example` as in `flutter test integration_test/plugin_integration_test.dart`.

## Development
### Bindings generation (`dart run ffigen --config ffigen.yaml`)
Bindings are generated using [ffigen](https://pub.dev/packages/ffigen).  After bindings are generated, wrap the bound functions in `flutter_libsparkmobile.dart`.

### `sparkmobile` troubleshooting
If you need to test changes in `sparkmobile` itself, you may need to install Boost development libraries as in `sudo apt install libboost-all-dev`.
