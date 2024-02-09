import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libsparkmobile/src/extensions.dart';
import 'package:flutter_libsparkmobile/src/models/spark_coin.dart';

import 'src/flutter_libsparkmobile_bindings_generated.dart';

export 'src/models/spark_coin.dart';

const kSparkChain = 0x6;
const kSparkChange = 0x270F;
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
    required final Uint8List context,
    final bool isTestNet = false,
  }) {
    // take sublist as tx hash is also appended here for some reason
    final b64CoinDecoded = base64Decode(serializedCoin).sublist(0, 244);

    final serializedCoinPtr = b64CoinDecoded.unsignedCharPointer();
    final privateKeyPtr =
        privateKeyHex.to32BytesFromHex().unsignedCharPointer();
    final contextPtr = context.unsignedCharPointer();

    final result = _bindings.idAndRecoverCoin(
      serializedCoinPtr,
      b64CoinDecoded.length,
      privateKeyPtr,
      index,
      contextPtr,
      context.length,
      isTestNet ? 1 : 0,
    );

    malloc.free(serializedCoinPtr);
    malloc.free(privateKeyPtr);
    malloc.free(contextPtr);

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
      nonceHex: result.ref.nonceHex
          .cast<Utf8>()
          .toDartString(length: result.ref.nonceHexLength),
      address: result.ref.address.cast<Utf8>().toDartString(),
      value: BigInt.from(result.ref.value),
      memo: result.ref.memo.cast<Utf8>().toDartString(),
      diversifier: BigInt.from(result.ref.diversifier),
      encryptedDiversifier: result.ref.encryptedDiversifier
          .toUint8List(result.ref.encryptedDiversifierLength),
      serial: result.ref.serial.toUint8List(result.ref.serialLength),
      lTagHash: result.ref.lTagHash.cast<Utf8>().toDartString(),
    );

    malloc.free(result.ref.address);
    malloc.free(result.ref.memo);
    malloc.free(result.ref.lTagHash);
    malloc.free(result.ref.encryptedDiversifier);
    malloc.free(result.ref.nonceHex);
    malloc.free(result.ref.serial);
    malloc.free(result);

    return ret;
  }

  static Uint8List serializeMintContext({required List<(String, int)> inputs}) {
    final inputsPtr =
        malloc.allocate<DartInputData>(sizeOf<DartInputData>() * inputs.length);

    for (int i = 0; i < inputs.length; i++) {
      final hash =
          Uint8List.fromList(inputs[i].$1.to32BytesFromHex().reversed.toList());

      inputsPtr[i].txHashLength = hash.length;
      inputsPtr[i].txHash = hash.unsignedCharPointer();
      inputsPtr[i].vout = inputs[i].$2;
    }

    final result = _bindings.serializeMintContext(inputsPtr, inputs.length);

    final serialized = result.ref.context.toUint8List(result.ref.contextLength);

    for (int i = 0; i < inputs.length; i++) {
      malloc.free(inputsPtr[i].txHash);
    }
    malloc.free(inputsPtr);
    malloc.free(result.ref.context);
    malloc.free(result);

    return serialized;
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
    Uint8List serializedSpendPayload,
    List<Uint8List> outputScripts,
    int fee,
    List<
        ({
          String serializedCoin,
          String serializedCoinContext,
          int groupId,
          int height,
        })> usedCoins,
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
    required List<
            ({
              String serializedCoin,
              String serializedCoinContext,
              int groupId,
              int height,
            })>
        serializedCoins,
    required List<
            ({
              int setId,
              String setHash,
              List<({String serializedCoin, String txHash})> set
            })>
        allAnonymitySets,
    required List<
            ({
              int setId,
              Uint8List blockHash,
            })>
        idAndBlockHashes,
    required Uint8List txHash,
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
    for (int i = 0; i < privateRecipients.length; i++) {
      privateRecipientsPtr[i].subtractFee =
          privateRecipients[i].subtractFeeFromAmount ? 1 : 0;

      privateRecipientsPtr[i].output =
          malloc.allocate<COutputCoinData>(sizeOf<COutputCoinData>());
      privateRecipientsPtr[i].output.ref.value = privateRecipients[i].amount;
      privateRecipientsPtr[i].output.ref.memoLength =
          privateRecipients[i].memo.length;
      privateRecipientsPtr[i].output.ref.memo =
          privateRecipients[i].memo.toNativeUtf8().cast<Char>();
      privateRecipientsPtr[i].output.ref.addressLength =
          privateRecipients[i].sparkAddress.length;
      privateRecipientsPtr[i].output.ref.address =
          privateRecipients[i].sparkAddress.toNativeUtf8().cast<Char>();
    }

    final serializedCoinsPtr = malloc.allocate<DartSpendCoinData>(
        sizeOf<DartSpendCoinData>() * serializedCoins.length);
    for (int i = 0; i < serializedCoins.length; i++) {
      final b64CoinDecoded = base64Decode(serializedCoins[i].serializedCoin);
      serializedCoinsPtr[i].serializedCoin =
          malloc.allocate<CCDataStream>(sizeOf<CCDataStream>());
      serializedCoinsPtr[i].serializedCoin.ref.data =
          b64CoinDecoded.unsignedCharPointer();
      serializedCoinsPtr[i].serializedCoin.ref.length = b64CoinDecoded.length;

      final b64ContextDecoded =
          base64Decode(serializedCoins[i].serializedCoinContext);
      serializedCoinsPtr[i].serializedCoinContext =
          malloc.allocate<CCDataStream>(sizeOf<CCDataStream>());
      serializedCoinsPtr[i].serializedCoinContext.ref.data =
          b64ContextDecoded.unsignedCharPointer();
      serializedCoinsPtr[i].serializedCoinContext.ref.length =
          b64ContextDecoded.length;

      serializedCoinsPtr[i].groupId = serializedCoins[i].groupId;
      serializedCoinsPtr[i].height = serializedCoins[i].height;
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

    final idAndBlockHashesPtr = malloc.allocate<BlockHashAndId>(
        sizeOf<BlockHashAndId>() * idAndBlockHashes.length);
    for (int i = 0; i < idAndBlockHashes.length; i++) {
      assert(idAndBlockHashes[i].blockHash.length == 32);
      idAndBlockHashesPtr[i].id = idAndBlockHashes[i].setId;
      idAndBlockHashesPtr[i].hash =
          idAndBlockHashes[i].blockHash.unsignedCharPointer();
    }

    final txHashPtr = txHash.unsignedCharPointer();

    final result = _bindings.cCreateSparkSpendTransaction(
      privateKeyPtr,
      index,
      recipientsPtr,
      recipients.length,
      privateRecipientsPtr,
      privateRecipients.length,
      serializedCoinsPtr,
      serializedCoins.length,
      coverSetDataAllPtr,
      allAnonymitySets.length,
      idAndBlockHashesPtr,
      idAndBlockHashes.length,
      txHashPtr,
    );

    malloc.free(privateKeyPtr);
    malloc.free(recipientsPtr);

    for (int i = 0; i < privateRecipients.length; i++) {
      malloc.free(privateRecipientsPtr[i].output.ref.memo);
      malloc.free(privateRecipientsPtr[i].output.ref.address);
      malloc.free(privateRecipientsPtr[i].output);
    }
    malloc.free(privateRecipientsPtr);

    for (int i = 0; i < serializedCoins.length; i++) {
      malloc.free(serializedCoinsPtr[i].serializedCoinContext.ref.data);
      malloc.free(serializedCoinsPtr[i].serializedCoinContext);
      malloc.free(serializedCoinsPtr[i].serializedCoin.ref.data);
      malloc.free(serializedCoinsPtr[i].serializedCoin);
    }
    malloc.free(serializedCoinsPtr);

    for (int i = 0; i < allAnonymitySets.length; i++) {
      for (int j = 0; j < allAnonymitySets[i].set.length; j++) {
        malloc.free(coverSetDataAllPtr[i].cover_set[j].data);
      }
      malloc.free(coverSetDataAllPtr[i].cover_set);
      malloc.free(coverSetDataAllPtr[i].cover_set_representation);
    }
    malloc.free(coverSetDataAllPtr);

    for (int i = 0; i < idAndBlockHashes.length; i++) {
      malloc.free(idAndBlockHashesPtr[i].hash);
    }
    malloc.free(idAndBlockHashesPtr);

    malloc.free(txHashPtr);

    if (result.address == nullptr.address) {
      throw Exception(
        "createSparkSendTransaction() failed for an unknown reason",
      );
    }

    final messageBytes = result.ref.data.toUint8List(result.ref.dataLength);

    malloc.free(result.ref.data);

    if (result.ref.isError > 0) {
      final message = utf8.decode(messageBytes);
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

    final List<
        ({
          String serializedCoin,
          String serializedCoinContext,
          int groupId,
          int height,
        })> usedCoins = [];

    for (int i = 0; i < result.ref.usedCoinsLength; i++) {
      final coinRef = result.ref.usedCoins[i].serializedCoin.ref;
      final contextRef = result.ref.usedCoins[i].serializedCoinContext.ref;

      usedCoins.add((
        serializedCoin:
            coinRef.data.cast<Utf8>().toDartString(length: coinRef.length),
        serializedCoinContext: contextRef.data
            .cast<Utf8>()
            .toDartString(length: contextRef.length),
        groupId: result.ref.usedCoins[i].groupId,
        height: result.ref.usedCoins[i].height,
      ));

      malloc.free(result.ref.usedCoins[i].serializedCoin.ref.data);
      malloc.free(result.ref.usedCoins[i].serializedCoin);
      malloc.free(result.ref.usedCoins[i].serializedCoinContext.ref.data);
      malloc.free(result.ref.usedCoins[i].serializedCoinContext);
    }

    malloc.free(result.ref.usedCoins);

    return (
      serializedSpendPayload: messageBytes,
      fee: fee,
      outputScripts: scripts,
      usedCoins: usedCoins,
    );
  }

  static bool validateAddress({
    required String address,
    required bool isTestNet,
  }) {
    final addressPtr = address.toNativeUtf8().cast<Char>();

    final result = _bindings.isValidSparkAddress(
      addressPtr,
      isTestNet ? 1 : 0,
    );

    malloc.free(addressPtr);

    if (result.address != nullptr.address) {
      final isValid = result.ref.isValid > 0;
      final String message;

      if (result.ref.errorMessage.address == nullptr.address) {
        message = "";
      } else {
        message = result.ref.errorMessage.cast<Utf8>().toDartString();
        malloc.free(result.ref.errorMessage);
      }
      malloc.free(result);

      if (kDebugMode && message.isNotEmpty) {
        debugPrint("validateAddress error message: $message");
      }

      return isValid;
    } else {
      // some error occurred result in null being returned which should happen
      // but is checked anyways
      if (kDebugMode) {
        debugPrint("validateAddress ffi called returned nullptr");
      }
      return false;
    }
  }

  static Set<String> hashTags({required Set<String> base64Tags}) {
    if (base64Tags.isEmpty) {
      return {};
    }

    final bytes = Uint8List.fromList(
      base64Tags.expand((e) => base64Decode(e)).toList(),
    );

    final result = _bindings.hashTags(
      bytes.unsignedCharPointer(),
      base64Tags.length,
    );

    final Set<String> hashes = {};

    for (int i = 0; i < base64Tags.length; i++) {
      final hash =
          result.elementAt(i * 64).cast<Utf8>().toDartString(length: 64);
      hashes.add(hash);
    }

    malloc.free(result);

    return hashes;
  }

  static String hashTag(String x, String y) {
    final xPtr = x.toNativeUtf8().cast<Char>();
    final yPtr = y.toNativeUtf8().cast<Char>();

    final result = _bindings.hashTag(xPtr, yPtr);
    final hash = result.cast<Utf8>().toDartString();

    malloc.free(xPtr);
    malloc.free(yPtr);
    malloc.free(result);

    return hash;
  }

  static int estimateSparkFee({
    required String privateKeyHex,
    int index = 1,
    required int sendAmount,
    required bool subtractFeeFromAmount,
    required List<
            ({
              String serializedCoin,
              String serializedCoinContext,
              int groupId,
              int height,
            })>
        serializedCoins,
    required int privateRecipientsCount,
  }) {
    final privateKeyPtr =
        privateKeyHex.to32BytesFromHex().unsignedCharPointer();

    final serializedCoinsPtr = malloc.allocate<DartSpendCoinData>(
        sizeOf<DartSpendCoinData>() * serializedCoins.length);
    for (int i = 0; i < serializedCoins.length; i++) {
      final b64CoinDecoded = base64Decode(serializedCoins[i].serializedCoin);
      serializedCoinsPtr[i].serializedCoin =
          malloc.allocate<CCDataStream>(sizeOf<CCDataStream>());
      serializedCoinsPtr[i].serializedCoin.ref.data =
          b64CoinDecoded.unsignedCharPointer();
      serializedCoinsPtr[i].serializedCoin.ref.length = b64CoinDecoded.length;

      final b64ContextDecoded =
          base64Decode(serializedCoins[i].serializedCoinContext);
      serializedCoinsPtr[i].serializedCoinContext =
          malloc.allocate<CCDataStream>(sizeOf<CCDataStream>());
      serializedCoinsPtr[i].serializedCoinContext.ref.data =
          b64ContextDecoded.unsignedCharPointer();
      serializedCoinsPtr[i].serializedCoinContext.ref.length =
          b64ContextDecoded.length;

      serializedCoinsPtr[i].groupId = serializedCoins[i].groupId;
      serializedCoinsPtr[i].height = serializedCoins[i].height;
    }

    final result = _bindings.estimateSparkFee(
      privateKeyPtr,
      index,
      sendAmount,
      subtractFeeFromAmount ? 1 : 0,
      serializedCoinsPtr,
      serializedCoins.length,
      privateRecipientsCount,
    );

    for (int i = 0; i < serializedCoins.length; i++) {
      malloc.free(serializedCoinsPtr[i].serializedCoinContext);
      malloc.free(serializedCoinsPtr[i].serializedCoin);
    }
    malloc.free(serializedCoinsPtr);
    malloc.free(privateKeyPtr);

    if (result.ref.error.address != nullptr.address) {
      final ex = Exception(
        result.ref.error.cast<Utf8>().toDartString(),
      );
      malloc.free(result.ref.error);
      malloc.free(result);
      throw ex;
    } else {
      final fee = result.ref.fee;
      malloc.free(result);
      return fee;
    }
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
