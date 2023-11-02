import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'flutter_libsparkmobile_bindings.dart';
import 'flutter_libsparkmobile_platform_interface.dart';

class FlutterLibsparkmobile {
  final SparkMobileBindings _bindings;

  FlutterLibsparkmobile(DynamicLibrary dynamicLibrary)
      : _bindings = SparkMobileBindings(dynamicLibrary);

  Future<String?> getPlatformVersion() {
    return FlutterLibsparkmobilePlatform.instance.getPlatformVersion();
  }

  // SparkMobileBindings methods
  Future<String> generateSpendKey() {
    Pointer<Char> key = _bindings.generateSpendKey();

    // Cast the Pointer<Char> to a Dart String.
    final keyString = key.cast<Utf8>().toDartString();

    return Future.value(keyString);
  }
}
