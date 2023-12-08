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
  /// Create spark mint recipients
  ///
  /// Returns a list of spark mint recipients
  ///
  static List<
      ({
        Uint8List scriptPubKey,
        int amount,
        bool subtractFeeFromAmount,
      })> createSparkMintRecipients({
    required List<({String sparkAddress, int value, String memo})> outputs,
    required Uint8List serialContext,
    bool generate = false,
  }) {
    final outputsPtr = malloc
        .allocate<CMintedCoinData>(sizeOf<CMintedCoinData>() * outputs.length);

    for (int i = 0; i < outputs.length; i++) {
      outputsPtr[i].value = outputs[i].value;
      outputsPtr[i].address =
          outputs[i].sparkAddress.toNativeUtf8().cast<Char>();
      outputsPtr[i].memo = outputs[i].memo.toNativeUtf8().cast<Char>();
    }

    final serialContextPtr = serialContext.unsignedCharPointer();

    final result = _bindings.cCreateSparkMintRecipients(
      outputsPtr,
      outputs.length,
      serialContextPtr,
      serialContext.length,
      generate ? 1 : 0,
    );

    if (result.address == nullptr.address) {
      for (int i = 0; i < outputs.length; i++) {
        malloc.free(outputsPtr[i].address);
        malloc.free(outputsPtr[i].memo);
      }
      malloc.free(outputsPtr);
      throw Exception("createSparkMintRecipients() FFI call returned null!");
    }

    final List<
        ({
          Uint8List scriptPubKey,
          int amount,
          bool subtractFeeFromAmount,
        })> ret = [];

    for (int i = 0; i < result.ref.length; i++) {
      final d = result.ref.list[i];
      ret.add((
        scriptPubKey: d.pubKey.toUint8List(d.pubKeyLength),
        amount: d.cAmount,
        subtractFeeFromAmount: d.subtractFee > 0,
      ));
      malloc.free(d.pubKey);
    }

    malloc.free(result.ref.list);
    malloc.free(result);
    for (int i = 0; i < outputs.length; i++) {
      malloc.free(outputsPtr[i].address);
      malloc.free(outputsPtr[i].memo);
    }
    malloc.free(outputsPtr);

    return ret;
  }

  ///
  /// Attempt to create a spark spend.
  ///
  /// Returns the serialized spark spend.
  ///
  static ({
    String serializedSpendPayload,
    List<Uint8List> outputScripts,
    int fee,
  }) createSparkSendTransaction({
    required String privateKeyHex,
    int index = 1,
    required List<({String address, int amount, bool subtractFeeFromAmount})>
        recipients,
    required List<
            ({
              String sparkAddress,
              int amount,
              bool subtractFeeFromAmount,
              String memo
            })>
        privateRecipients,
    required List<Uint8List> serializedMintMetas,
    required List<
            ({
              int setId,
              String setHash,
              List<({String serializedCoin, String txHash})> set
            })>
        allAnonymitySets,
  }) {
    final privateKeyPtr =
        privateKeyHex.to32BytesFromHex().unsignedCharPointer();

    final recipientsPtr =
        malloc.allocate<CRecip>(sizeOf<CRecip>() * recipients.length);
    for (int i = 0; i < recipients.length; i++) {
      recipientsPtr[i].amount = recipients[i].amount;
      recipientsPtr[i].subtractFee =
          recipients[i].subtractFeeFromAmount ? 1 : 0;
    }

    final privateRecipientsPtr = malloc.allocate<COutputRecipient>(
        sizeOf<COutputRecipient>() * recipients.length);
    for (int i = 0; i < recipients.length; i++) {
      privateRecipientsPtr[i].subtractFee =
          recipients[i].subtractFeeFromAmount ? 1 : 0;

      privateRecipientsPtr[i].output =
          malloc.allocate<COutputCoinData>(sizeOf<COutputCoinData>());
      privateRecipientsPtr[i].output.ref.value = privateRecipients[i].amount;
      privateRecipientsPtr[i].output.ref.memo =
          privateRecipients[i].memo.toNativeUtf8().cast<Char>();
      privateRecipientsPtr[i].output.ref.address =
          privateRecipients[i].sparkAddress.toNativeUtf8().cast<Char>();
    }

    final serializedMintMetasPtr = malloc.allocate<CCDataStream>(
        sizeOf<CCDataStream>() * serializedMintMetas.length);
    for (int i = 0; i < serializedMintMetas.length; i++) {
      serializedMintMetasPtr[i].data =
          serializedMintMetas[i].unsignedCharPointer();
      serializedMintMetasPtr[i].length = serializedMintMetas[i].length;
    }

    final coverSetDataAllPtr = malloc.allocate<CCoverSetData>(
        sizeOf<CCoverSetData>() * allAnonymitySets.length);
    for (int i = 0; i < allAnonymitySets.length; i++) {
      coverSetDataAllPtr[i].setId = allAnonymitySets[i].setId;

      coverSetDataAllPtr[i].cover_set = malloc.allocate<CCDataStream>(
          sizeOf<CCDataStream>() * allAnonymitySets[i].set.length);
      coverSetDataAllPtr[i].cover_setLength = allAnonymitySets[i].set.length;

      for (int j = 0; j < allAnonymitySets[i].set.length; j++) {
        final b64CoinDecoded =
            base64Decode(allAnonymitySets[i].set[j].serializedCoin);
        coverSetDataAllPtr[i].cover_set[j].length = b64CoinDecoded.length;
        coverSetDataAllPtr[i].cover_set[j].data =
            b64CoinDecoded.unsignedCharPointer();
      }

      final setHash = base64Decode(allAnonymitySets[i].setHash);
      coverSetDataAllPtr[i].cover_set_representation =
          setHash.unsignedCharPointer();
      coverSetDataAllPtr[i].cover_set_representationLength = setHash.length;
    }

    final result = _bindings.cCreateSparkSpendTransaction(
      privateKeyPtr,
      index,
      recipientsPtr,
      recipients.length,
      privateRecipientsPtr,
      privateRecipients.length,
      serializedMintMetasPtr,
      serializedMintMetas.length,
      coverSetDataAllPtr,
      allAnonymitySets.length,
    );

    // todo: more comprehensive frees
    malloc.free(privateKeyPtr);
    malloc.free(recipientsPtr);
    malloc.free(privateRecipientsPtr);
    malloc.free(serializedMintMetasPtr);
    malloc.free(coverSetDataAllPtr);

    if (result.address == nullptr.address) {
      throw Exception(
        "createSparkSendTransaction() failed for an unknown reason",
      );
    }

    final messageBytes = result.ref.data.toUint8List(result.ref.dataLength);
    final message = utf8.decode(messageBytes);
    malloc.free(result.ref.data);

    if (result.ref.isError > 0) {
      throw Exception(message);
    }

    final fee = result.ref.fee;

    final List<Uint8List> scripts = [];
    for (int i = 0; i < result.ref.outputScriptsLength; i++) {
      final script = result.ref.outputScripts[i].bytes
          .toUint8List(result.ref.outputScripts[i].length);
      malloc.free(result.ref.outputScripts[i].bytes);
      scripts.add(script);
    }

    malloc.free(result.ref.outputScripts);

    return (serializedSpendPayload: message, fee: fee, outputScripts: scripts);
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
