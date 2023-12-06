import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_libsparkmobile/src/extensions.dart';
import 'package:flutter_libsparkmobile/src/models/spark_coin.dart';

import 'src/flutter_libsparkmobile_bindings_generated.dart';

const kSparkChain = 6;
const kSparkBaseDerivationPath = "m/44'/136'/0'/$kSparkChain/";
const kSparkBaseDerivationPathTestnet = "m/44'/1'/0'/$kSparkChain/";

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
    final keyDataPointer = privateKey.unsignedCharPointer();

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
    final String serializedCoin, {
    required final String privateKeyHex,
    required final int index,
    final bool isTestNet = false,
  }) {
    // take sublist as tx hash is also appended here for some reason
    final b64CoinDecoded = base64Decode(serializedCoin).sublist(0, 244);

    final serializedCoinPtr = b64CoinDecoded.unsignedCharPointer();
    final privateKeyPtr =
        privateKeyHex.to32BytesFromHex().unsignedCharPointer();

    final result = _bindings.idAndRecoverCoin(
      serializedCoinPtr,
      b64CoinDecoded.length,
      privateKeyPtr,
      index,
      isTestNet ? 1 : 0,
    );

    malloc.free(serializedCoinPtr);
    malloc.free(privateKeyPtr);

    if (result.address == nullptr.address) {
      return null;
    }

    final LibSparkCoinType coinType;
    switch (result.ref.type) {
      case 0:
        coinType = LibSparkCoinType.mint;
        break;
      case 1:
        coinType = LibSparkCoinType.mint;
        break;
      default:
        throw Exception("Unknown coin type \"${result.ref.type}\" found.");
    }

    final ret = LibSparkCoin(
      type: coinType,
      nonce: result.ref.nonce.toUint8List(result.ref.nonceLength),
      address: result.ref.address.cast<Utf8>().toDartString(),
      value: BigInt.from(result.ref.value),
      memo: result.ref.memo.cast<Utf8>().toDartString(),
      diversifier: BigInt.from(result.ref.diversifier),
      encryptedDiversifier:
          result.ref.serial.toUint8List(result.ref.encryptedDiversifierLength),
      serial: result.ref.serial.toUint8List(result.ref.serialLength),
      lTagHash: result.ref.lTagHash.cast<Utf8>().toDartString(),
    );

    malloc.free(result.ref.address);
    malloc.free(result.ref.memo);
    malloc.free(result.ref.lTagHash);
    malloc.free(result.ref.encryptedDiversifier);
    malloc.free(result.ref.nonce);
    malloc.free(result.ref.serial);
    malloc.free(result);

    return ret;
  }

  ///
  /// Attempt to create and sign a spark mint transaction.
  ///
  /// Returns the raw transaction hex if successful, otherwise null.
  ///
  static String? createSparkMintTransaction({
    required String privateKeyHex,
    // TODO what do we need?
  }) {
    // TODO allocate/create data structures required by the generated bindings

    // some kind of failure
    return null;
  }

  ///
  /// Attempt to create and sign a spark spend transaction.
  ///
  /// Returns the raw transaction hex if successful, otherwise null.
  ///
  static String? createSparkSendTransaction({
    required String privateKeyHex,
    // TODO what do we need?
  }) {
    // TODO allocate/create data structures required by the generated bindings

    // some kind of failure
    return null;
  }
}

extension on Pointer<UnsignedChar> {
  Uint8List toUint8List(int length) {
    // TODO needs free?
    return Uint8List.fromList(cast<Uint8>().asTypedList(length));
  }
}

extension on Uint8List {
  Pointer<UnsignedChar> unsignedCharPointer() {
    final pointer = malloc.allocate<Uint8>(sizeOf<Uint8>() * lengthInBytes);
    pointer.asTypedList(lengthInBytes).setAll(0, this);
    return pointer.cast<UnsignedChar>();
  }
}
