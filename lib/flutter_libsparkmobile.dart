import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_libsparkmobile/src/extensions.dart';
import 'package:flutter_libsparkmobile/src/logging.dart';
import 'package:flutter_libsparkmobile/src/models/spark_coin.dart';

import 'src/flutter_libsparkmobile_bindings_generated.dart';

export 'src/logging.dart';
export 'src/models/spark_coin.dart';

const kSparkChain = 0x6;
const kSparkChange = 0x270F;
const kSparkBaseDerivationPath = "m/44'/136'/0'/$kSparkChain/";
const kSparkBaseDerivationPathTestnet = "m/44'/1'/0'/$kSparkChain/";

const kMaxNameLength =
    20; // max 20 symbols, alphanumerical or "-_.", case-insensitive
const kNameRegexString = r'^[a-zA-Z0-9\-_\.]+$';
const kMaxAdditionalInfoLengthBytes = 1024;
const kMaxNameRegistrationLengthYears = 10;
const kStage3DevelopmentFundAddressMainNet =
    "aLgRaYSFk6iVw2FqY1oei8Tdn2aTsGPVmP";
const kStage3DevelopmentFundAddressTestNet =
    "TWDxLLKsFp6qcV1LL4U2uNmW4HwMcapmMU";
const kStandardSparkNamesFee = [
  -1,
  1000,
  100,
  10,
  10,
  10,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
];

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

bool get enableDebugLogging =>
    Log.onLog != null && Log.levels.contains(LoggingLevel.debug);

bool get enableTraceLogging =>
    Log.onLog != null && Log.levels.contains(LoggingLevel.trace);

abstract final class LibSpark {
  static final FlutterLibsparkmobileBindings _bindings =
      FlutterLibsparkmobileBindings(_dylib);

  // trace call id
  static int _id = 0;

  // SparkMobileBindings methods:

  /// Derive an address from the keyData (mnemonic).
  static Future<String> getAddress({
    required Uint8List privateKey,
    required int index,
    required int diversifier,
    bool isTestNet = false,
  }) async {
    DateTime? start;
    int? id;
    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(privateKey=REDACTED,"
            "index=$index,"
            "diversifier=$diversifier,"
            "isTestNet=$isTestNet)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }
    try {
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

      final keyDataPointer = privateKey.unsignedCharPointer();

      final addressPointer = _bindings.getAddress(
        keyDataPointer,
        index,
        diversifier,
        isTestNet ? 1 : 0,
      );

      final addressString = addressPointer.cast<Utf8>().toDartString();

      freeDart(keyDataPointer, debugName: "keyDataPointer");
      freeNative(addressPointer, debugName: "addressPointer");
      return addressString;
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
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
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(serializedCoin=$serializedCoin,"
            "privateKeyHex=REDACTED,"
            "index=$index,"
            "context=$context,"
            "isTestNet=$isTestNet)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
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

      freeDart(serializedCoinPtr, debugName: "serializedCoinPtr");
      freeDart(privateKeyPtr, debugName: "privateKeyPtr");
      freeDart(contextPtr, debugName: "contextPtr");
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

      freeNative(result.ref.address, debugName: "result.ref.address");
      freeNative(result.ref.memo, debugName: "result.ref.memo");
      freeNative(result.ref.lTagHash, debugName: "result.ref.lTagHash");
      freeNative(
        result.ref.encryptedDiversifier,
        debugName: "result.ref.encryptedDiversifier",
      );
      freeNative(result.ref.nonceHex, debugName: "result.ref.nonceHex");
      freeNative(result.ref.serial, debugName: "result.ref.serial");
      freeNative(result, debugName: "result");

      return ret;
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static Uint8List serializeMintContext({required List<(String, int)> inputs}) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(inputs=$inputs)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      final inputsPtr = malloc
          .allocate<DartInputData>(sizeOf<DartInputData>() * inputs.length);

      for (int i = 0; i < inputs.length; i++) {
        final hash = Uint8List.fromList(
          inputs[i].$1.to32BytesFromHex().reversed.toList(),
        );

        inputsPtr[i].txHashLength = hash.length;
        inputsPtr[i].txHash = hash.unsignedCharPointer();
        inputsPtr[i].vout = inputs[i].$2;
      }

      final result = _bindings.serializeMintContext(inputsPtr, inputs.length);

      final serialized =
          result.ref.context.toUint8List(result.ref.contextLength);

      for (int i = 0; i < inputs.length; i++) {
        freeDart(inputsPtr[i].txHash, debugName: "inputsPtr[$i].txHash");
      }
      freeDart(inputsPtr, debugName: "inputsPtr");
      freeNative(result.ref.context, debugName: "result.ref.context");
      freeNative(result, debugName: "result");

      return serialized;
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
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
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(outputs=$outputs,"
            "serialContext=$serialContext,"
            "generate=$generate)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      final outputsPtr = malloc.allocate<CMintedCoinData>(
        sizeOf<CMintedCoinData>() * outputs.length,
      );

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
          freeDart(outputsPtr[i].address, debugName: "outputsPtr[$i].address");
          freeDart(outputsPtr[i].memo, debugName: "outputsPtr[$i].memo");
        }
        freeDart(outputsPtr, debugName: "outputsPtr");
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
        ret.add(
          (
            scriptPubKey: d.pubKey.toUint8List(d.pubKeyLength),
            amount: d.cAmount,
            subtractFeeFromAmount: d.subtractFee > 0,
          ),
        );
        freeNative(d.pubKey, debugName: "d.pubKey");
      }

      freeNative(result.ref.list, debugName: "result.ref.list");
      freeNative(result, debugName: "result");
      for (int i = 0; i < outputs.length; i++) {
        freeDart(outputsPtr[i].address, debugName: "outputsPtr[$i].address");
        freeDart(outputsPtr[i].memo, debugName: "outputsPtr[$i].memo");
      }
      freeDart(outputsPtr, debugName: "outputsPtr");
      return ret;
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
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
    required int additionalTxSize,
  }) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(privateKeyHex=REDACTED,"
            "index=$index,"
            "recipients=$recipients,"
            "privateRecipients=$privateRecipients,"
            "serializedCoins=$serializedCoins,"
            "allAnonymitySets=$allAnonymitySets,"
            "idAndBlockHashes=$idAndBlockHashes,"
            "txHash=$txHash)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
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
        sizeOf<COutputRecipient>() * privateRecipients.length,
      );
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
        sizeOf<DartSpendCoinData>() * serializedCoins.length,
      );
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
        sizeOf<CCoverSetData>() * allAnonymitySets.length,
      );
      for (int i = 0; i < allAnonymitySets.length; i++) {
        coverSetDataAllPtr[i].setId = allAnonymitySets[i].setId;

        coverSetDataAllPtr[i].cover_set = malloc.allocate<CCDataStream>(
          sizeOf<CCDataStream>() * allAnonymitySets[i].set.length,
        );
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
        sizeOf<BlockHashAndId>() * idAndBlockHashes.length,
      );
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
        additionalTxSize,
      );

      freeDart(privateKeyPtr, debugName: "privateKeyPtr");
      freeDart(recipientsPtr, debugName: "recipientsPtr");
      for (int i = 0; i < privateRecipients.length; i++) {
        freeDart(
          privateRecipientsPtr[i].output.ref.memo,
          debugName: "privateRecipientsPtr[$i].output.ref.memo",
        );
        freeDart(
          privateRecipientsPtr[i].output.ref.address,
          debugName: "privateRecipientsPtr[$i].output.ref.address",
        );
        freeDart(
          privateRecipientsPtr[i].output,
          debugName: "privateRecipientsPtr[$i].output",
        );
      }
      freeDart(privateRecipientsPtr, debugName: "privateRecipientsPtr");
      for (int i = 0; i < serializedCoins.length; i++) {
        freeDart(
          serializedCoinsPtr[i].serializedCoinContext.ref.data,
          debugName: "serializedCoinsPtr[$i].serializedCoinContext.ref.data",
        );
        freeDart(
          serializedCoinsPtr[i].serializedCoinContext,
          debugName: "serializedCoinsPtr[$i].serializedCoinContext",
        );
        freeDart(
          serializedCoinsPtr[i].serializedCoin.ref.data,
          debugName: "serializedCoinsPtr[$i].serializedCoin.ref.data",
        );
        freeDart(
          serializedCoinsPtr[i].serializedCoin,
          debugName: "serializedCoinsPtr[$i].serializedCoin",
        );
      }
      freeDart(serializedCoinsPtr, debugName: "serializedCoinsPtr");

      for (int i = 0; i < allAnonymitySets.length; i++) {
        for (int j = 0; j < allAnonymitySets[i].set.length; j++) {
          freeDart(
            coverSetDataAllPtr[i].cover_set[j].data,
            debugName: "coverSetDataAllPtr[$i].cover_set[j].data",
          );
        }
        freeDart(
          coverSetDataAllPtr[i].cover_set,
          debugName: "coverSetDataAllPtr[$i].cover_set",
        );
        freeDart(
          coverSetDataAllPtr[i].cover_set_representation,
          debugName: "coverSetDataAllPtr[$i].cover_set_representation",
        );
      }
      freeDart(coverSetDataAllPtr, debugName: "coverSetDataAllPtr");
      for (int i = 0; i < idAndBlockHashes.length; i++) {
        freeDart(
          idAndBlockHashesPtr[i].hash,
          debugName: "idAndBlockHashesPtr[$i].hash",
        );
      }
      freeDart(idAndBlockHashesPtr, debugName: "idAndBlockHashesPtr");
      freeDart(txHashPtr, debugName: "txHashPtr");
      if (result.address == nullptr.address) {
        throw Exception(
          "createSparkSendTransaction() failed for an unknown reason",
        );
      }

      final messageBytes = result.ref.data.toUint8List(result.ref.dataLength);

      freeNative(result.ref.data, debugName: "result.ref.data");

      if (result.ref.isError > 0) {
        final message = utf8.decode(messageBytes);
        throw Exception(message);
      }

      final fee = result.ref.fee;

      final List<Uint8List> scripts = [];
      for (int i = 0; i < result.ref.outputScriptsLength; i++) {
        final script = result.ref.outputScripts[i].bytes
            .toUint8List(result.ref.outputScripts[i].length);
        freeNative(
          result.ref.outputScripts[i].bytes,
          debugName: "result.ref.outputScripts[$i].bytes",
        );
        scripts.add(script);
      }

      freeNative(
        result.ref.outputScripts,
        debugName: "result.ref.outputScripts",
      );

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

        usedCoins.add(
          (
            serializedCoin: coinRef.data.toBase64(coinRef.length),
            serializedCoinContext: contextRef.data.toBase64(contextRef.length),
            groupId: result.ref.usedCoins[i].groupId,
            height: result.ref.usedCoins[i].height,
          ),
        );

        freeNative(
          result.ref.usedCoins[i].serializedCoin.ref.data,
          debugName: "result.ref.usedCoins[$i].serializedCoin.ref.data",
        );
        freeNative(
          result.ref.usedCoins[i].serializedCoin,
          debugName: "result.ref.usedCoins[$i].serializedCoin",
        );
        freeNative(
          result.ref.usedCoins[i].serializedCoinContext.ref.data,
          debugName: "result.ref.usedCoins[$i].serializedCoinContext.ref.data",
        );
        freeNative(
          result.ref.usedCoins[i].serializedCoinContext,
          debugName: "result.ref.usedCoins[$i].serializedCoinContext",
        );
      }

      freeNative(result.ref.usedCoins, debugName: "result.ref.usedCoins");

      return (
        serializedSpendPayload: messageBytes,
        fee: fee,
        outputScripts: scripts,
        usedCoins: usedCoins,
      );
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static bool validateAddress({
    required String address,
    required bool isTestNet,
  }) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(address=$address,"
            "isTestNet=$isTestNet)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }
    try {
      final addressPtr = address.toNativeUtf8().cast<Char>();

      final result = _bindings.isValidSparkAddress(
        addressPtr,
        isTestNet ? 1 : 0,
      );

      freeDart(addressPtr, debugName: "addressPtr");
      if (result.address != nullptr.address) {
        final isValid = result.ref.isValid > 0;
        final String message;

        if (result.ref.errorMessage.address == nullptr.address) {
          message = "";
        } else {
          message = result.ref.errorMessage.cast<Utf8>().toDartString();
          freeNative(
            result.ref.errorMessage,
            debugName: "result.ref.errorMessage",
          );
        }
        freeNative(result, debugName: "result");

        if (message.isNotEmpty) {
          Log.w("validateAddress error message: $message");
        }

        return isValid;
      } else {
        // some error occurred result in null being returned which should happen
        // but is checked anyways
        Log.w("validateAddress ffi called returned nullptr");

        return false;
      }
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static Set<String> hashTags({required Set<String> base64Tags}) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(base64Tags=$base64Tags)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }
    try {
      if (base64Tags.isEmpty) {
        return {};
      }

      final bytesPointer = Uint8List.fromList(
        base64Tags.expand((e) => base64Decode(e)).toList(),
      ).unsignedCharPointer();

      final result = _bindings.hashTags(
        bytesPointer,
        base64Tags.length,
      );

      freeDart(bytesPointer, debugName: "bytesPointer");
      final Set<String> hashes = {};

      for (int i = 0; i < base64Tags.length; i++) {
        final hash =
            result.elementAt(i * 64).cast<Utf8>().toDartString(length: 64);
        hashes.add(hash);
      }

      freeNative(result, debugName: "result");

      return hashes;
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static String hashTag(String x, String y) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(x=$x, y=$y)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      final xPtr = x.toNativeUtf8().cast<Char>();
      final yPtr = y.toNativeUtf8().cast<Char>();

      final result = _bindings.hashTag(xPtr, yPtr);
      final hash = result.cast<Utf8>().toDartString();

      freeDart(xPtr, debugName: "xPtr");
      freeDart(yPtr, debugName: "yPtr");
      freeNative(result, debugName: "result");

      return hash;
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
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
    required int utxoNum,
    required int additionalTxSize,
  }) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "(privateKeyHex=REDACTED,"
            "index=$index,"
            "sendAmount=$sendAmount,"
            "subtractFeeFromAmount=$subtractFeeFromAmount,"
            "privateRecipientsCount=$privateRecipientsCount,"
            "serializedCoins=${serializedCoins.length})";
      }
      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      final privateKeyPtr =
          privateKeyHex.to32BytesFromHex().unsignedCharPointer();

      final serializedCoinsPtr = malloc.allocate<DartSpendCoinData>(
        sizeOf<DartSpendCoinData>() * serializedCoins.length,
      );
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
        utxoNum,
        additionalTxSize,
      );

      for (int i = 0; i < serializedCoins.length; i++) {
        freeDart(
          serializedCoinsPtr[i].serializedCoinContext,
          debugName: "serializedCoinsPtr[$i].serializedCoinContext",
        );
        freeDart(
          serializedCoinsPtr[i].serializedCoin,
          debugName: "serializedCoinsPtr[$i].serializedCoin",
        );
      }
      freeDart(serializedCoinsPtr, debugName: "serializedCoinsPtr");
      freeDart(privateKeyPtr, debugName: "privateKeyPtr");

      if (result.ref.error.address != nullptr.address) {
        final ex = Exception(
          result.ref.error.cast<Utf8>().toDartString(),
        );
        freeNative(result.ref.error, debugName: "result.ref.error");
        freeNative(result, debugName: "result");
        throw ex;
      } else {
        final fee = result.ref.fee;
        freeNative(result, debugName: "result");
        return fee;
      }
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static ({Uint8List script, int size}) createSparkNameScript({
    required int sparkNameValidityBlocks,
    required String name,
    required String additionalInfo,
    required String scalarHex,
    required String privateKeyHex,
    required int spendKeyIndex,
    required int diversifier,
    required bool isTestNet,
    required int hashFailSafe,
    required bool ignoreProof,
  }) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = StackTrace.current.functionName;
      if (enableTraceLogging) {
        function += "("
            "sparkNameValidityBlocks=$sparkNameValidityBlocks,"
            "name=$name,"
            "additionalInfo=$additionalInfo,"
            "privateKeyPtr=REDACTED,"
            "spendKeyIndex=$spendKeyIndex,"
            "diversifier=$diversifier,"
            "isTestNet=$isTestNet,"
            ")";
      }
      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      final namePtr = name.toNativeUtf8().cast<Char>();
      final additionalInfoPtr = additionalInfo.toNativeUtf8().cast<Char>();
      final scalarHexPtr = scalarHex.toNativeUtf8().cast<Char>();
      final privateKeyPtr =
          privateKeyHex.to32BytesFromHex().unsignedCharPointer();

      final result = _bindings.createSparkNameScript(
        sparkNameValidityBlocks,
        namePtr,
        additionalInfoPtr,
        scalarHexPtr,
        privateKeyPtr,
        spendKeyIndex,
        diversifier,
        isTestNet ? 1 : 0,
        hashFailSafe,
        ignoreProof ? 1 : 0,
      );

      freeDart(namePtr, debugName: "namePtr");
      freeDart(additionalInfoPtr, debugName: "additionalInfoPtr");
      freeDart(privateKeyPtr, debugName: "privateKeyPtr");

      if (result.address == nullptr.address) {
        throw Exception("Internal memory allocation likely failed");
      }

      Uint8List? script;
      String? errorMessage;
      int? size;

      if (result.ref.error.address != nullptr.address) {
        errorMessage = result.ref.error.cast<Utf8>().toDartString();
        freeNative(result.ref.error, debugName: "result.ref.error");
      }

      if (result.ref.script.address != nullptr.address) {
        script = result.ref.script.toUint8List(result.ref.scriptLength);

        freeNative(result.ref.script, debugName: "result.ref.script");
      }

      size = result.ref.size +
          20; // https://github.com/firoorg/firo/blob/dd2a537d52c177736284f568e494dafb55db4924/src/spark/sparkwallet.cpp#L1624C59-L1624C123

      freeNative(result, debugName: "result");

      if (script == null) {
        errorMessage ??=
            "Internal memory allocation for error message likely failed";
        throw Exception(errorMessage);
      }

      return (script: script, size: size);
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) ${StackTrace.current.functionName}"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static void freeNative<T extends NativeType>(
    Pointer<T> pointer, {
    required String debugName,
  }) {
    if (enableDebugLogging) {
      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "Freeing $debugName $pointer using native `free` via FFI",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }
    _bindings.native_free(pointer.cast());
  }

  static void freeDart<T extends NativeType>(
    Pointer<T> pointer, {
    required String debugName,
  }) {
    if (enableDebugLogging) {
      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "Freeing $debugName $pointer using Dart's `malloc.free`",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }
    malloc.free(pointer);
  }
}

extension on Pointer<UnsignedChar> {
  Uint8List toUint8List(int length) {
    // TODO needs free?
    return Uint8List.fromList(cast<Uint8>().asTypedList(length));
  }

  String toBase64(int length) {
    final data = toUint8List(length);
    return base64.encode(data);
  }
}

extension on Uint8List {
  Pointer<UnsignedChar> unsignedCharPointer() {
    final pointer = malloc.allocate<Uint8>(sizeOf<Uint8>() * lengthInBytes);
    pointer.asTypedList(lengthInBytes).setAll(0, this);
    return pointer.cast<UnsignedChar>();
  }
}
