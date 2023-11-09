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

  /// Derive an address from the keyData (mnemonic).
  Future<String> getAddress(
      List<int> keyData, int index, int diversifier) async {
    final keyDataHex = _toHexString(keyData);

    // Allocate memory for the hex string on the native heap.
    final keyDataPointer = keyDataHex.toNativeUtf8().cast<Char>();

    // Call the native method with the pointer.
    final addressPointer =
        _bindings.getAddress(keyDataPointer, index, diversifier);

    // Convert the Pointer<Char> to a Dart String.
    final addressString = addressPointer.cast<Utf8>().toDartString();

    // Free the native heap allocated memory.
    malloc.free(keyDataPointer);
    malloc.free(addressPointer);

    return addressString;
  }

  // Utility methods:

  /// Convert List<int> keyData to a hex string.
  ///
  /// TODO make extension.
  String _toHexString(List<int> keyData) {
    return keyData.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
