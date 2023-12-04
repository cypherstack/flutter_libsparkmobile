import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_libsparkmobile/src/models/spark_coin.dart';

import 'src/extensions.dart';
import 'src/flutter_libsparkmobile_bindings_generated.dart';

const kSparkChain = 6;
const kSparkBaseDerivationPath = "m/44'/136'/0'/$kSparkChain/";

const String _kLibName = 'flutter_libsparkmobile';

/// The dynamic library in which the symbols for [FlutterLibsparkmobileBindings] can be found.
final DynamicLibrary _dylib = () {
  // TODO: Make available in test somehow. Not sure if easily possible atm

  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_kLibName.framework/$_kLibName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_kLibName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_kLibName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

abstract final class LibSpark {
  static final FlutterLibsparkmobileBindings _bindings =
      FlutterLibsparkmobileBindings(_dylib);

  // SparkMobileBindings methods:

  /// Derive an address from the keyData (mnemonic).
  static Future<String> getAddress({
    required Uint8List privateKey,
    required int index,
    required int diversifier,
    bool isTestNet = false,
  }) async {
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
    final addressPointer = _bindings.getAddress(
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

  ///
  /// Check whether the spark coin is ours and if so recover required data
  /// and encapsulate into a single object ([LibSparkCoin]).
  ///
  /// Returns a [LibSparkCoin] if the coin belongs to us, or null otherwise.
  ///
  static LibSparkCoin? identifyAndRecoverCoin(
    String serializedCoin, {
    required String privateKeyHex,
    required int index,
  }) {
    final result = _bindings.identifyCoin(
      serializedCoin.toNativeUtf8().cast<Char>(),
      serializedCoin.length,
      privateKeyHex.toNativeUtf8().cast<Char>(),
      index,
    );

    throw UnimplementedError(
      "Have ffi return all the data we need for SparkCoin."
      " This may or may not encompass all fields currently in SparkCoin.",
    );
  }
}

extension on Uint8List {
  Pointer<UnsignedChar> unsignedCharPointer() {
    final pointer = malloc.allocate<Uint8>(sizeOf<Uint8>() * lengthInBytes);
    pointer.asTypedList(lengthInBytes).setAll(0, this);
    return pointer.cast<UnsignedChar>();
  }
}
