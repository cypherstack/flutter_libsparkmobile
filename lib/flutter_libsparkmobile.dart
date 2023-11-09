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

  Future<String> getAddress(
      List<int> keyData, int index, int diversifier) async {
    // Allocate space for the key data on the native heap.
    final keyDataPointer = malloc.allocate<Int>(keyData.length);

    // Copy the key data into the allocated space.
    for (int i = 0; i < keyData.length; i++) {
      keyDataPointer[i] = keyData[i];
    }

    // Call the native method with the pointer.
    final addressPointer = _bindings
        .getAddress(keyDataPointer, keyData.length, index, diversifier)
        .cast<Utf8>();

    // Convert the Pointer<Utf8> to a Dart String.
    final addressString = addressPointer.toDartString();

    // Free the native heap allocated memory for the key data.
    malloc.free(keyDataPointer);

    // The native side allocated memory for the returned address,
    // it needs to be freed after copying it to Dart-controlled memory.
    final String result = addressString;
    malloc.free(addressPointer);

    return result;
  }
}
