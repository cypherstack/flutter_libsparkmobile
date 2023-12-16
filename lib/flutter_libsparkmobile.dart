import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
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
      encryptedDiversifier:
          result.ref.serial.toUint8List(result.ref.encryptedDiversifierLength),
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

    // TODO frees

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

  static ({int changeToMint, List<LibSparkCoin> coins}) getCoinsToSpend({
    required int sendAmount,
    required int recipientsToSubtractFee,
    required List<LibSparkCoin> coins,
    required int privateRecipientsCount,
    required int recipientsCount,
  }) {
    final coinsPtr = malloc.allocate<CCSparkMintMeta>(
      sizeOf<CCSparkMintMeta>() * coins.length,
    );

    for (int i = 0; i < coins.length; i++) {
      coinsPtr[i].height = coins[i].height!;
      coinsPtr[i].id = coins[i].id!;
      coinsPtr[i].isUsed = coins[i].isUsed! ? 1 : 0;
      coinsPtr[i].txid = coins[i].txHash!.unsignedCharPointer();
      coinsPtr[i].i = coins[i].diversifier!.toInt();
      coinsPtr[i].d = coins[i].encryptedDiversifier!.unsignedCharPointer();
      coinsPtr[i].dLength = coins[i].encryptedDiversifier!.length;
      coinsPtr[i].nonceHex = coins[i].nonceHex!.toNativeUtf8().cast<Char>();
      coinsPtr[i].nonceHexLength = coins[i].nonceHex!.length;
      coinsPtr[i].memo = coins[i].memo!.toNativeUtf8().cast<Char>();
      coinsPtr[i].memoLength = coins[i].memo!.length;
      coinsPtr[i].serial_context =
          coins[i].serialContext!.unsignedCharPointer();
      coinsPtr[i].serial_contextLength = coins[i].serialContext!.length;
      coinsPtr[i].type = coins[i].type.value;

      final serCoin = base64Decode(coins[i].serializedCoin!);
      coinsPtr[i].serializedCoin = serCoin.unsignedCharPointer();
      coinsPtr[i].serializedCoinLength = serCoin.length;
    }

    final result = _bindings.getCoinsToSpend(
      sendAmount,
      coinsPtr,
      coins.length,
    );

    for (int i = 0; i < coins.length; i++) {
      malloc.free(coinsPtr[i].txid);
      malloc.free(coinsPtr[i].d);
      malloc.free(coinsPtr[i].nonceHex);
      malloc.free(coinsPtr[i].memo);
      malloc.free(coinsPtr[i].serial_context);
      malloc.free(coinsPtr[i].serializedCoin);
    }
    malloc.free(coinsPtr);

    if (result.ref.errorMessageLength > 0) {
      final ex = Exception(
        result.ref.errorMessage.cast<Utf8>().toDartString(
              length: result.ref.errorMessageLength,
            ),
      );
      malloc.free(result.ref.errorMessage);
      malloc.free(result);
      throw ex;
    }

    final ({int changeToMint, List<LibSparkCoin> coins}) ret = (
      changeToMint: result.ref.changeToMint,
      coins: <LibSparkCoin>[],
    );

    for (int i = 0; i < result.ref.length; i++) {
      final LibSparkCoinType coinType;
      switch (result.ref.list[i].type) {
        case 0:
          coinType = LibSparkCoinType.mint;
          break;
        case 1:
          coinType = LibSparkCoinType.mint;
          break;
        default:
          throw Exception(
            "Unknown coin type \"${result.ref.list[i].type}\" found.",
          );
      }

      final coin = LibSparkCoin(
        type: coinType,
        id: result.ref.list[i].id,
        height: result.ref.list[i].height,
        isUsed: result.ref.list[i].isUsed > 0,
        nonceHex: result.ref.list[i].nonceHex
            .cast<Utf8>()
            .toDartString(length: result.ref.list[i].nonceHexLength),
        value: BigInt.from(result.ref.list[i].v),
        memo: result.ref.list[i].memo
            .cast<Utf8>()
            .toDartString(length: result.ref.list[i].memoLength),
        txHash: result.ref.list[i].txid.toUint8List(32),
        serialContext: result.ref.list[i].serial_context
            .toUint8List(result.ref.list[i].serial_contextLength),
        diversifier: BigInt.from(result.ref.list[i].i),
        encryptedDiversifier:
            result.ref.list[i].d.toUint8List(result.ref.list[i].dLength),
        serializedCoin: base64Encode(result.ref.list[i].serializedCoin
            .toUint8List(result.ref.list[i].serializedCoinLength)),
      );

      ret.coins.add(coin);

      malloc.free(result.ref.list[i].txid);
      malloc.free(result.ref.list[i].d);
      malloc.free(result.ref.list[i].nonceHex);
      malloc.free(result.ref.list[i].memo);
      malloc.free(result.ref.list[i].serial_context);
      malloc.free(result.ref.list[i].serializedCoin);
    }

    malloc.free(result);

    return ret;
  }

  static ({int fee, List<LibSparkCoin> coins}) selectSparkCoins({
    required int requiredAmount,
    required bool subtractFeeFromAmount,
    required List<LibSparkCoin> coins,
    required int privateRecipientsCount,
  }) {
    final coinsPtr = malloc.allocate<CCSparkMintMeta>(
      sizeOf<CCSparkMintMeta>() * coins.length,
    );

    for (int i = 0; i < coins.length; i++) {
      coinsPtr[i].height = coins[i].height!;
      coinsPtr[i].id = coins[i].id!;
      coinsPtr[i].isUsed = coins[i].isUsed! ? 1 : 0;
      coinsPtr[i].txid = coins[i].txHash!.unsignedCharPointer();
      coinsPtr[i].i = coins[i].diversifier!.toInt();
      coinsPtr[i].d = coins[i].encryptedDiversifier!.unsignedCharPointer();
      coinsPtr[i].dLength = coins[i].encryptedDiversifier!.length;
      coinsPtr[i].nonceHex = coins[i].nonceHex!.toNativeUtf8().cast<Char>();
      coinsPtr[i].nonceHexLength = coins[i].nonceHex!.length;
      coinsPtr[i].memo = coins[i].memo!.toNativeUtf8().cast<Char>();
      coinsPtr[i].memoLength = coins[i].memo!.length;
      coinsPtr[i].serial_context =
          coins[i].serialContext!.unsignedCharPointer();
      coinsPtr[i].serial_contextLength = coins[i].serialContext!.length;
      coinsPtr[i].type = coins[i].type.value;

      final serCoin = base64Decode(coins[i].serializedCoin!);
      coinsPtr[i].serializedCoin = serCoin.unsignedCharPointer();
      coinsPtr[i].serializedCoinLength = serCoin.length;
    }

    final result = _bindings.selectSparkCoins(
      requiredAmount,
      subtractFeeFromAmount ? 1 : 0,
      coinsPtr,
      coins.length,
      privateRecipientsCount,
    );

    for (int i = 0; i < coins.length; i++) {
      malloc.free(coinsPtr[i].txid);
      malloc.free(coinsPtr[i].d);
      malloc.free(coinsPtr[i].nonceHex);
      malloc.free(coinsPtr[i].memo);
      malloc.free(coinsPtr[i].serial_context);
      malloc.free(coinsPtr[i].serializedCoin);
    }
    malloc.free(coinsPtr);

    if (result.ref.errorMessageLength > 0) {
      final ex = Exception(
        result.ref.errorMessage.cast<Utf8>().toDartString(
              length: result.ref.errorMessageLength,
            ),
      );
      malloc.free(result.ref.errorMessage);
      malloc.free(result);
      throw ex;
    }

    final ({int fee, List<LibSparkCoin> coins}) ret = (
      fee: result.ref.fee,
      coins: <LibSparkCoin>[],
    );

    for (int i = 0; i < result.ref.length; i++) {
      final LibSparkCoinType coinType;
      switch (result.ref.list[i].type) {
        case 0:
          coinType = LibSparkCoinType.mint;
          break;
        case 1:
          coinType = LibSparkCoinType.mint;
          break;
        default:
          throw Exception(
            "Unknown coin type \"${result.ref.list[i].type}\" found.",
          );
      }

      final coin = LibSparkCoin(
        type: coinType,
        id: result.ref.list[i].id,
        height: result.ref.list[i].height,
        isUsed: result.ref.list[i].isUsed > 0,
        nonceHex: result.ref.list[i].nonceHex
            .cast<Utf8>()
            .toDartString(length: result.ref.list[i].nonceHexLength),
        value: BigInt.from(result.ref.list[i].v),
        memo: result.ref.list[i].memo
            .cast<Utf8>()
            .toDartString(length: result.ref.list[i].memoLength),
        txHash: result.ref.list[i].txid.toUint8List(32),
        serialContext: result.ref.list[i].serial_context
            .toUint8List(result.ref.list[i].serial_contextLength),
        diversifier: BigInt.from(result.ref.list[i].i),
        encryptedDiversifier:
            result.ref.list[i].d.toUint8List(result.ref.list[i].dLength),
        serializedCoin: base64Encode(result.ref.list[i].serializedCoin
            .toUint8List(result.ref.list[i].serializedCoinLength)),
      );

      ret.coins.add(coin);

      malloc.free(result.ref.list[i].txid);
      malloc.free(result.ref.list[i].d);
      malloc.free(result.ref.list[i].nonceHex);
      malloc.free(result.ref.list[i].memo);
      malloc.free(result.ref.list[i].serial_context);
      malloc.free(result.ref.list[i].serializedCoin);
    }

    malloc.free(result);

    return ret;
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
