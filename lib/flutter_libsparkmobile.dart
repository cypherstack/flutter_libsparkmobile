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

  // SparkMobileBindings methods:

  Future<String> getAddress(String keyData, int index, int diversifier) {
    // Convert the Dart String to a Pointer<Char>.
    final keyDataPointer = keyData.toNativeUtf8().cast<Char>();

    // Call the native method.
    Pointer<Char> addressPointer =
        _bindings.getAddress(keyDataPointer, index, diversifier);

    // Cast the Pointer<Char> to a Dart String.
    final addressString = addressPointer.cast<Utf8>().toDartString();

    // It's a good idea to free the native string after use if the native method allocates memory.
    malloc.free(addressPointer);

    // It's also important to free any pointers that were allocated to pass parameters.
    malloc.free(keyDataPointer);

    return Future.value(addressString);
  }
}
