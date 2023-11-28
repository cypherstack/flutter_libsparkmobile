import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_libsparkmobile/extensions.dart';

import 'flutter_libsparkmobile_bindings.dart';

const kSparkChain = 6;
const kSparkBaseDerivationPath = "m/44'/136'/0'/$kSparkChain/";

abstract final class LibSpark {
  static SparkMobileBindings? _bindings;

  static void _checkLoaded() {
    _bindings ??= SparkMobileBindings(_loadLibrary());
  }

  static DynamicLibrary _loadLibrary() {
    // hack in prefix for test env
    String testPrefix = "";
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      if (Platform.isLinux) {
        testPrefix = 'scripts/linux/build/';
      } else if (Platform.isMacOS) {
        testPrefix = 'scripts/macos/build/';
      } else if (Platform.isWindows) {
        testPrefix = 'scripts/windows/build/';
      } else {
        throw UnsupportedError('This platform is not supported');
      }
    }

    if (Platform.isLinux) {
      return DynamicLibrary.open('${testPrefix}libsparkmobile.so');
    } else if (Platform.isAndroid) {
      // return DynamicLibrary.open('${testPrefix}libsparkmobile.so');
    } else if (Platform.isIOS) {
      // return DynamicLibrary.open('${testPrefix}libsparkmobile.dylib');
    } else if (Platform.isMacOS) {
      // return DynamicLibrary.open('${testPrefix}libsparkmobile.dylib');
    } else if (Platform.isWindows) {
      // return DynamicLibrary.open('${testPrefix}sparkmobile.dll');
    }
    throw UnsupportedError('This platform is not supported');
  }

  // SparkMobileBindings methods:

  /// Derive an address from the keyData (mnemonic).
  static Future<String> getAddress({
    required Uint8List privateKey,
    required int index,
    required int diversifier,
    bool isTestNet = false,
  }) async {
    _checkLoaded();

    if (index < 0) {
      throw Exception("Index must not be negative.");
    }

    if (diversifier < 0) {
      throw Exception("Diversifier must not be negative.");
    }

    if (privateKey.length != 32) {
      throw Exception(
        "Invalid private key length: ${privateKey.length}. Must be 32 bytes.",
      );
    }

    // Allocate memory for the hex string on the native heap.
    final keyDataPointer = privateKey.toHexString().toNativeUtf8().cast<Char>();

    // Call the native method with the pointer.
    final addressPointer = _bindings!.getAddress(
      keyDataPointer,
      index,
      diversifier,
      isTestNet ? 1 : 0,
    );

    // Convert the Pointer<Char> to a Dart String.
    final addressString = addressPointer.cast<Utf8>().toDartString();

    // Free the native heap allocated memory.
    malloc.free(keyDataPointer);
    malloc.free(addressPointer);

    return addressString;
  }
}
