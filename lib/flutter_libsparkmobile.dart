import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/extensions.dart';
import 'src/flutter_libsparkmobile_bindings_generated.dart';
import 'src/logging.dart';
import 'src/models/spark_coin.dart';
import 'src/models/spark_spend_version.dart';

export 'src/logging.dart';
export 'src/models/spark_coin.dart';
export 'src/models/spark_spend_version.dart';

const kSparkChain = 0x6;
const kSparkChange = 0x270F;
const kSparkBaseDerivationPath = "m/44'/136'/0'/$kSparkChain/";
const kSparkBaseDerivationPathTestnet = "m/44'/1'/0'/$kSparkChain/";

const kMaxNameLength =
    20; // max 20 symbols, alphanumerical or "-.", case-insensitive
const kNameRegexString = r'^[a-zA-Z0-9.-]+$';
const kMaxAdditionalInfoLengthBytes = 1024;
const kMaxNameRegistrationLengthYears = 10;
const kStage3CommunityFundAddressMainNet = "aFA2TbqG9cnhhzX5Yny2pBJRK5EaEqLCH7";
const kStage3DCommunityFundAddressTestNet =
    "TCkC4uoErEyCB4MK3d6ouyJELoXnuyqe9L";
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

bool get enableDebugLogging =>
    Log.onLog != null &&
    (Log.levels.contains(LoggingLevel.debug) ||
        Log.levels.contains(LoggingLevel.trace));

bool get enableTraceLogging =>
    Log.onLog != null && Log.levels.contains(LoggingLevel.trace);

abstract final class LibSpark {
  static int _id = 0;

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
      String function = 'LibSpark.getAddress';
      if (enableTraceLogging) {
        function +=
            "(privateKey=REDACTED,"
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

      _checkInt32(index, 'index');
      _checkInt32(diversifier, 'diversifier');
      return using<String>((arena) {
        final address = _requirePointer(
          native_getAddress(
            privateKey.unsignedCharPointer(arena),
            index,
            diversifier,
            isTestNet ? 1 : 0,
          ),
        );
        try {
          return address.cast<Utf8>().toDartString();
        } finally {
          freeNative(address, debugName: 'address');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.getAddress"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static Future<String> getAddressFromFullViewKey({
    required String fullViewKeyHex,
    required int index,
    required int diversifier,
    bool isTestNet = false,
  }) async {
    _checkInt32(index, 'index');
    _checkInt32(diversifier, 'diversifier');
    final fullViewKey = _deserializeFullViewKey(fullViewKeyHex: fullViewKeyHex);
    try {
      final address = _requirePointer(
        native_getAddressFromFullViewKey(
          fullViewKey,
          index,
          diversifier,
          isTestNet ? 1 : 0,
        ),
      );
      try {
        return address.cast<Utf8>().toDartString();
      } finally {
        freeNative(address, debugName: 'address');
      }
    } finally {
      _deleteFullViewKey(fullViewKey);
    }
  }

  static Uint8List serializeMintContext({required List<(String, int)> inputs}) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = 'LibSpark.serializeMintContext';
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
      _checkInt32(inputs.length, 'inputs.length');
      for (final input in inputs) {
        _checkInt32(input.$2, 'vout');
      }
      return using((arena) {
        final inputsPtr = arena<DartInputData>(inputs.length);
        for (int i = 0; i < inputs.length; i++) {
          final hash = Uint8List.fromList(
            inputs[i].$1.to32BytesFromHex().reversed.toList(),
          );
          inputsPtr[i].txHashLength = hash.length;
          inputsPtr[i].txHash = hash.unsignedCharPointer(arena);
          inputsPtr[i].vout = inputs[i].$2;
        }
        final result = _requirePointer(
          native_serializeMintContext(inputsPtr, inputs.length),
        );
        try {
          return result.ref.context.toUint8List(result.ref.contextLength);
        } finally {
          freeNative(result.ref.context, debugName: 'result.context');
          freeNative(result, debugName: 'result');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.serializeMintContext"
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
    ({Uint8List scriptPubKey, int amount, bool subtractFeeFromAmount})
  >
  createSparkMintRecipients({
    required List<({String sparkAddress, int value, String memo})> outputs,
    required Uint8List serialContext,
    bool generate = false,
  }) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = 'LibSpark.createSparkMintRecipients';
      if (enableTraceLogging) {
        function +=
            "(outputs=$outputs,"
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
      _checkInt32(outputs.length, 'outputs.length');
      _checkInt32(serialContext.length, 'serialContext.length');
      for (final output in outputs) {
        _checkCString(output.sparkAddress, 'sparkAddress');
      }
      return using((arena) {
        final outputsPtr = arena<CMintedCoinData>(outputs.length);
        for (int i = 0; i < outputs.length; i++) {
          final memo = utf8.encode(outputs[i].memo);
          _checkInt32(memo.length, 'memo.length');
          outputsPtr[i].value = outputs[i].value;
          outputsPtr[i].address = outputs[i].sparkAddress
              .toNativeUtf8(allocator: arena)
              .cast<Char>();
          outputsPtr[i].memo = memo.unsignedCharPointer(arena).cast<Char>();
          outputsPtr[i].memoLength = memo.length;
        }
        final result = _requirePointer(
          native_cCreateSparkMintRecipients(
            outputsPtr,
            outputs.length,
            serialContext.unsignedCharPointer(arena),
            serialContext.length,
            generate ? 1 : 0,
          ),
        );
        try {
          return [
            for (int i = 0; i < result.ref.length; i++)
              (
                scriptPubKey: result.ref.list[i].pubKey.toUint8List(
                  result.ref.list[i].pubKeyLength,
                ),
                amount: result.ref.list[i].cAmount,
                subtractFeeFromAmount: result.ref.list[i].subtractFee > 0,
              ),
          ];
        } finally {
          for (int i = 0; i < result.ref.length; i++) {
            freeNative(
              result.ref.list[i].pubKey,
              debugName: 'recipient.pubKey',
            );
          }
          freeNative(result.ref.list, debugName: 'result.list');
          freeNative(result, debugName: 'result');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.createSparkMintRecipients"
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
      })
    >
    usedCoins,
  })
  createSparkSendTransaction({
    required String privateKeyHex,
    int index = 1,
    required List<({String address, int amount, bool subtractFeeFromAmount})>
    recipients,
    required List<
      ({
        String sparkAddress,
        int amount,
        bool subtractFeeFromAmount,
        String memo,
      })
    >
    privateRecipients,
    required List<
      ({
        String serializedCoin,
        String serializedCoinContext,
        int groupId,
        int height,
      })
    >
    serializedCoins,
    required List<
      ({
        int setId,
        String setHash,
        List<({String serializedCoin, String txHash})> set,
      })
    >
    allAnonymitySets,
    required List<({int setId, Uint8List blockHash})> idAndBlockHashes,
    required Uint8List txHash,
    required int additionalTxSize,
    required SparkSpendVersion spendVersion,
    Uint8List? extensionCommitment,
  }) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = 'LibSpark.createSparkSendTransaction';
      if (enableTraceLogging) {
        function +=
            "(privateKeyHex=REDACTED,"
            "index=$index,"
            "recipients=$recipients,"
            "privateRecipients=$privateRecipients,"
            "serializedCoins=$serializedCoins,"
            "allAnonymitySets=$allAnonymitySets,"
            "idAndBlockHashes=$idAndBlockHashes,"
            "txHash=$txHash,"
            "spendVersion=$spendVersion)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      _checkInt32(index, 'index');
      _checkInt32(additionalTxSize, 'additionalTxSize');
      _checkBytes(txHash, 32, 'txHash');
      _checkInt32(recipients.length, 'recipients.length');
      _checkInt32(privateRecipients.length, 'privateRecipients.length');
      _checkInt32(serializedCoins.length, 'serializedCoins.length');
      _checkInt32(allAnonymitySets.length, 'allAnonymitySets.length');
      _checkInt32(idAndBlockHashes.length, 'idAndBlockHashes.length');
      for (final recipient in privateRecipients) {
        _checkCString(recipient.sparkAddress, 'sparkAddress');
      }
      for (final set in allAnonymitySets) {
        _checkInt32(set.setId, 'setId');
        _checkInt32(set.set.length, 'set.length');
      }
      for (final block in idAndBlockHashes) {
        _checkBytes(block.blockHash, 32, 'blockHash');
        _checkInt32(block.setId, 'setId');
      }
      final resolvedExtensionCommitment = spendVersion
          .resolveExtensionCommitment(extensionCommitment);
      return using((arena) {
        final privateKeyPtr = privateKeyHex
            .to32BytesFromHex()
            .unsignedCharPointer(arena);
        final recipientsPtr = arena<CRecip>(recipients.length);
        for (int i = 0; i < recipients.length; i++) {
          recipientsPtr[i].amount = recipients[i].amount;
          recipientsPtr[i].subtractFee = recipients[i].subtractFeeFromAmount
              ? 1
              : 0;
        }
        final privateRecipientsPtr = arena<COutputRecipient>(
          privateRecipients.length,
        );
        for (int i = 0; i < privateRecipients.length; i++) {
          final recipient = privateRecipients[i];
          final memo = utf8.encode(recipient.memo);
          final address = utf8.encode(recipient.sparkAddress);
          _checkInt32(memo.length, 'memo.length');
          _checkInt32(address.length, 'address.length');
          privateRecipientsPtr[i].subtractFee = recipient.subtractFeeFromAmount
              ? 1
              : 0;
          privateRecipientsPtr[i].output = arena<COutputCoinData>();
          final output = privateRecipientsPtr[i].output.ref;
          output.value = recipient.amount;
          output.memoLength = memo.length;
          output.memo = memo.unsignedCharPointer(arena).cast<Char>();
          output.addressLength = address.length;
          output.address = address.unsignedCharPointer(arena).cast<Char>();
        }
        final serializedCoinsPtr = _spendCoins(arena, serializedCoins);
        final coverSetDataAllPtr = arena<CCoverSetData>(
          allAnonymitySets.length,
        );
        for (int i = 0; i < allAnonymitySets.length; i++) {
          final set = allAnonymitySets[i];
          coverSetDataAllPtr[i].setId = set.setId;
          coverSetDataAllPtr[i].cover_set = arena<CCDataStream>(set.set.length);
          coverSetDataAllPtr[i].cover_setLength = set.set.length;
          for (int j = 0; j < set.set.length; j++) {
            final coin = base64Decode(set.set[j].serializedCoin);
            _checkInt32(coin.length, 'serializedCoin.length');
            coverSetDataAllPtr[i].cover_set[j].length = coin.length;
            coverSetDataAllPtr[i].cover_set[j].data = coin.unsignedCharPointer(
              arena,
            );
          }
          final setHash = base64Decode(set.setHash);
          _checkInt32(setHash.length, 'setHash.length');
          coverSetDataAllPtr[i].cover_set_representation = setHash
              .unsignedCharPointer(arena);
          coverSetDataAllPtr[i].cover_set_representationLength = setHash.length;
        }
        final idAndBlockHashesPtr = arena<BlockHashAndId>(
          idAndBlockHashes.length,
        );
        for (int i = 0; i < idAndBlockHashes.length; i++) {
          idAndBlockHashesPtr[i].id = idAndBlockHashes[i].setId;
          idAndBlockHashesPtr[i].hash = idAndBlockHashes[i].blockHash
              .unsignedCharPointer(arena);
        }
        final result = _requirePointer(
          native_cCreateSparkSpendTransaction(
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
            txHash.unsignedCharPointer(arena),
            additionalTxSize,
            spendVersion.nativeValue,
            resolvedExtensionCommitment.unsignedCharPointer(arena),
          ),
        );
        try {
          final payload = result.ref.data.toUint8List(result.ref.dataLength);
          if (result.ref.isError > 0) {
            throw Exception(utf8.decode(payload, allowMalformed: true));
          }
          return (
            serializedSpendPayload: payload,
            fee: result.ref.fee,
            outputScripts: [
              for (int i = 0; i < result.ref.outputScriptsLength; i++)
                result.ref.outputScripts[i].bytes.toUint8List(
                  result.ref.outputScripts[i].length,
                ),
            ],
            usedCoins: [
              for (int i = 0; i < result.ref.usedCoinsLength; i++)
                (
                  serializedCoin: result
                      .ref
                      .usedCoins[i]
                      .serializedCoin
                      .ref
                      .data
                      .toBase64(
                        result.ref.usedCoins[i].serializedCoin.ref.length,
                      ),
                  serializedCoinContext: result
                      .ref
                      .usedCoins[i]
                      .serializedCoinContext
                      .ref
                      .data
                      .toBase64(
                        result
                            .ref
                            .usedCoins[i]
                            .serializedCoinContext
                            .ref
                            .length,
                      ),
                  groupId: result.ref.usedCoins[i].groupId,
                  height: result.ref.usedCoins[i].height,
                ),
            ],
          );
        } finally {
          _freeSpendResult(result);
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.createSparkSendTransaction"
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
      String function = 'LibSpark.validateAddress';
      if (enableTraceLogging) {
        function +=
            "(address=$address,"
            "isTestNet=$isTestNet)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }
    try {
      if (address.contains('\u0000')) {
        return false;
      }
      return using((arena) {
        final result = native_isValidSparkAddress(
          address.toNativeUtf8(allocator: arena).cast<Char>(),
          isTestNet ? 1 : 0,
        );
        if (result == nullptr) {
          Log.w(
            'validateAddress failed: ${_takeLastError() ?? 'unknown reason'}',
          );
          return false;
        }
        try {
          if (result.ref.errorMessage != nullptr) {
            Log.w(
              'validateAddress error message: ${result.ref.errorMessage.cast<Utf8>().toDartString()}',
            );
          }
          return result.ref.isValid > 0;
        } finally {
          freeNative(result.ref.errorMessage, debugName: 'result.errorMessage');
          freeNative(result, debugName: 'result');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.validateAddress"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static String createSparkAddressOwnershipProof({
    required String message,
    required String privateKeyHex,
    required int spendKeyIndex,
    required int diversifier,
  }) {
    final messageBytes = utf8.encode(message);
    _checkInt32(messageBytes.length, 'message.length');
    _checkInt32(spendKeyIndex, 'spendKeyIndex');
    _checkInt32(diversifier, 'diversifier');
    return using((arena) {
      final result = _requirePointer(
        native_createSparkAddressOwnershipProof(
          messageBytes.unsignedCharPointer(arena),
          messageBytes.length,
          privateKeyHex.to32BytesFromHex().unsignedCharPointer(arena),
          spendKeyIndex,
          diversifier,
        ),
      );
      try {
        if (result.ref.error != nullptr) {
          throw Exception(result.ref.error.cast<Utf8>().toDartString());
        }
        _requirePointer(result.ref.proof);
        if (result.ref.proofLength <= 0) {
          throw Exception('Failed to create Spark address ownership proof');
        }
        return result.ref.proof
            .cast<Uint8>()
            .asTypedList(result.ref.proofLength)
            .toHexString();
      } finally {
        freeNative(result.ref.error, debugName: 'result.error');
        freeNative(result.ref.proof, debugName: 'result.proof');
        freeNative(result, debugName: 'result');
      }
    });
  }

  static bool verifySparkAddressOwnershipProof({
    required String message,
    required String address,
    required String proof,
    required bool isTestNet,
  }) {
    if (proof.length != 260 ||
        address.isEmpty ||
        address.contains('\u0000') ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(proof)) {
      return false;
    }
    final messageBytes = utf8.encode(message);
    if (messageBytes.length > 0x7fffffff) {
      return false;
    }
    final proofBytes = Uint8List.fromList(
      List.generate(
        proof.length ~/ 2,
        (i) => int.parse(proof.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
    return using((arena) {
      return native_verifySparkAddressOwnershipProof(
            messageBytes.unsignedCharPointer(arena),
            messageBytes.length,
            address.toNativeUtf8(allocator: arena).cast<Char>(),
            proofBytes.unsignedCharPointer(arena),
            proofBytes.length,
            isTestNet ? 1 : 0,
          ) ==
          1;
    });
  }

  static List<String> hashTags({required List<String> base64Tags}) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = 'LibSpark.hashTags';
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
        return [];
      }
      _checkInt32(base64Tags.length, 'base64Tags.length');
      return using((arena) {
        final tags = arena<Uint8>(base64Tags.length * 34);
        final bytes = tags.asTypedList(base64Tags.length * 34);
        for (int i = 0; i < base64Tags.length; i++) {
          final tag = base64Decode(base64Tags[i]);
          _checkBytes(tag, 34, 'tag');
          bytes.setRange(i * 34, (i + 1) * 34, tag);
        }
        final result = _requirePointer(
          native_hashTags(tags.cast<UnsignedChar>(), base64Tags.length),
        );
        try {
          return [
            for (int i = 0; i < base64Tags.length; i++)
              (result + i * 64).cast<Utf8>().toDartString(length: 64),
          ];
        } finally {
          freeNative(result, debugName: 'result');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.hashTags"
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
      String function = 'LibSpark.hashTag';
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
      _checkCString(x, 'x');
      _checkCString(y, 'y');
      return using((arena) {
        final result = _requirePointer(
          native_hashTag(
            x.toNativeUtf8(allocator: arena).cast<Char>(),
            y.toNativeUtf8(allocator: arena).cast<Char>(),
          ),
        );
        try {
          return result.cast<Utf8>().toDartString();
        } finally {
          freeNative(result, debugName: 'result');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.hashTag"
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
      })
    >
    serializedCoins,
    required int privateRecipientsCount,
    required int utxoNum,
    required int additionalTxSize,
    required SparkSpendVersion spendVersion,
  }) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = 'LibSpark.estimateSparkFee';
      if (enableTraceLogging) {
        function +=
            "(privateKeyHex=REDACTED,"
            "index=$index,"
            "sendAmount=$sendAmount,"
            "subtractFeeFromAmount=$subtractFeeFromAmount,"
            "privateRecipientsCount=$privateRecipientsCount,"
            "serializedCoins=${serializedCoins.length},"
            "spendVersion=$spendVersion)";
      }
      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      _checkInt32(index, 'index');
      _checkInt32(privateRecipientsCount, 'privateRecipientsCount');
      _checkInt32(utxoNum, 'utxoNum');
      _checkInt32(additionalTxSize, 'additionalTxSize');
      _checkInt32(serializedCoins.length, 'serializedCoins.length');
      return using((arena) {
        final privateKeyPtr = privateKeyHex
            .to32BytesFromHex()
            .unsignedCharPointer(arena);
        final serializedCoinsPtr = _spendCoins(arena, serializedCoins);
        final result = _requirePointer(
          native_estimateSparkFee(
            privateKeyPtr,
            index,
            sendAmount,
            subtractFeeFromAmount ? 1 : 0,
            serializedCoinsPtr,
            serializedCoins.length,
            privateRecipientsCount,
            utxoNum,
            additionalTxSize,
            spendVersion.nativeValue,
          ),
        );
        try {
          if (result.ref.error != nullptr) {
            throw Exception(result.ref.error.cast<Utf8>().toDartString());
          }
          return result.ref.fee;
        } finally {
          freeNative(result.ref.error, debugName: 'result.error');
          freeNative(result, debugName: 'result');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.estimateSparkFee"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static ({Uint8List script, int size}) createSparkNameScript({
    required int sparkNameValidityBlocks,
    required String name,
    required String additionalInfo,
    required SparkNameProofInput proofInput,
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
      String function = 'LibSpark.createSparkNameScript';
      if (enableTraceLogging) {
        function +=
            "("
            "sparkNameValidityBlocks=$sparkNameValidityBlocks,"
            "name=$name,"
            "additionalInfo=$additionalInfo,"
            "spendVersion=${proofInput.spendVersion},"
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
      _checkInt32(sparkNameValidityBlocks, 'sparkNameValidityBlocks');
      _checkInt32(spendKeyIndex, 'spendKeyIndex');
      _checkInt32(diversifier, 'diversifier');
      _checkInt32(hashFailSafe, 'hashFailSafe', signed: true);
      _checkCString(name, 'name');
      _checkCString(additionalInfo, 'additionalInfo');
      return using((arena) {
        final ownershipDigest = Uint8List.fromList(
          proofInput.inputHex.to32BytesFromHex().reversed.toList(),
        );
        final result = _requirePointer(
          native_createSparkNameScript(
            sparkNameValidityBlocks,
            name.toNativeUtf8(allocator: arena).cast<Char>(),
            additionalInfo.toNativeUtf8(allocator: arena).cast<Char>(),
            ownershipDigest.unsignedCharPointer(arena),
            proofInput.spendVersion.nativeValue,
            privateKeyHex.to32BytesFromHex().unsignedCharPointer(arena),
            spendKeyIndex,
            diversifier,
            isTestNet ? 1 : 0,
            hashFailSafe,
            ignoreProof ? 1 : 0,
          ),
        );
        try {
          if (result.ref.error != nullptr) {
            throw Exception(result.ref.error.cast<Utf8>().toDartString());
          }
          _requirePointer(result.ref.script);
          return (
            script: result.ref.script.toUint8List(result.ref.scriptLength),
            size: result.ref.size + 20,
          );
        } finally {
          freeNative(result.ref.error, debugName: 'result.error');
          freeNative(result.ref.script, debugName: 'result.script');
          freeNative(result, debugName: 'result');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.createSparkNameScript"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  /// Returns the 32-byte extension commitment for serialized Spark Name data.
  ///
  /// [serializedSparkNameData] should be the `script` returned by
  /// [createSparkNameScript] with `ignoreProof: true`.
  static Uint8List getSparkNameCommitment({
    required Uint8List serializedSparkNameData,
  }) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = 'LibSpark.getSparkNameCommitment';
      if (enableTraceLogging) {
        function +=
            "(serializedSparkNameDataLength="
            "${serializedSparkNameData.length})";
      }
      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      if (serializedSparkNameData.isEmpty) {
        throw ArgumentError.value(
          serializedSparkNameData,
          'serializedSparkNameData',
          'must not be empty',
        );
      }
      _checkInt32(
        serializedSparkNameData.length,
        'serializedSparkNameData.length',
      );
      return using((arena) {
        final result = _requirePointer(
          native_cGetSparkNameCommitment(
            serializedSparkNameData.unsignedCharPointer(arena),
            serializedSparkNameData.length,
          ),
        );
        try {
          if (result.ref.error != nullptr) {
            throw Exception(result.ref.error.cast<Utf8>().toDartString());
          }
          _requirePointer(result.ref.commitment);
          if (result.ref.commitmentLength != 32) {
            throw Exception(
              'Unexpected Spark Name commitment length: ${result.ref.commitmentLength}',
            );
          }
          return result.ref.commitment.toUint8List(result.ref.commitmentLength);
        } finally {
          freeNative(result.ref.error, debugName: 'result.error');
          freeNative(result.ref.commitment, debugName: 'result.commitment');
          freeNative(result, debugName: 'result');
        }
      });
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark.getSparkNameCommitment"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }

  static void _checkInt32(int value, String name, {bool signed = false}) {
    RangeError.checkValueInInterval(
      value,
      signed ? -0x80000000 : 0,
      0x7fffffff,
      name,
    );
  }

  static void _checkBytes(Uint8List bytes, int length, String name) {
    if (bytes.length != length) {
      throw ArgumentError.value(bytes.length, name, 'must be $length bytes');
    }
  }

  static void _checkCString(String value, String name) {
    if (value.contains('\u0000')) {
      throw ArgumentError.value(value, name, 'must not contain NUL');
    }
  }

  static Pointer<T> _requirePointer<T extends NativeType>(Pointer<T> pointer) {
    if (pointer == nullptr) {
      throw Exception(_takeLastError() ?? 'Native call failed');
    }
    return pointer;
  }

  /// Returns and clears the reason the last native call on this thread failed.
  static String? _takeLastError() {
    final error = native_last_error();
    if (error == nullptr) {
      return null;
    }
    try {
      return utf8.decode(
        error.cast<Uint8>().asTypedList(error.cast<Utf8>().length),
        allowMalformed: true,
      );
    } finally {
      freeNative(error, debugName: 'error');
    }
  }

  static Pointer<DartSpendCoinData> _spendCoins(
    Arena arena,
    List<
      ({
        String serializedCoin,
        String serializedCoinContext,
        int groupId,
        int height,
      })
    >
    coins,
  ) {
    final pointer = arena<DartSpendCoinData>(coins.length);
    for (int i = 0; i < coins.length; i++) {
      _checkInt32(coins[i].groupId, 'groupId');
      _checkInt32(coins[i].height, 'height', signed: true);
      final coin = base64Decode(coins[i].serializedCoin);
      final context = base64Decode(coins[i].serializedCoinContext);
      _checkInt32(coin.length, 'serializedCoin.length');
      _checkInt32(context.length, 'serializedCoinContext.length');
      pointer[i].serializedCoin = arena<CCDataStream>();
      pointer[i].serializedCoin.ref.data = coin.unsignedCharPointer(arena);
      pointer[i].serializedCoin.ref.length = coin.length;
      pointer[i].serializedCoinContext = arena<CCDataStream>();
      pointer[i].serializedCoinContext.ref.data = context.unsignedCharPointer(
        arena,
      );
      pointer[i].serializedCoinContext.ref.length = context.length;
      pointer[i].groupId = coins[i].groupId;
      pointer[i].height = coins[i].height;
    }
    return pointer;
  }

  static void _freeSpendResult(Pointer<SparkSpendTransactionResult> result) {
    if (result.ref.isError == 0) {
      for (int i = 0; i < result.ref.outputScriptsLength; i++) {
        freeNative(
          result.ref.outputScripts[i].bytes,
          debugName: 'outputScript.bytes',
        );
      }
      freeNative(result.ref.outputScripts, debugName: 'result.outputScripts');
      for (int i = 0; i < result.ref.usedCoinsLength; i++) {
        final coin = result.ref.usedCoins[i];
        freeNative(coin.serializedCoin.ref.data, debugName: 'usedCoin.data');
        freeNative(coin.serializedCoin, debugName: 'usedCoin');
        freeNative(
          coin.serializedCoinContext.ref.data,
          debugName: 'usedCoinContext.data',
        );
        freeNative(coin.serializedCoinContext, debugName: 'usedCoinContext');
      }
      freeNative(result.ref.usedCoins, debugName: 'result.usedCoins');
    }
    freeNative(result.ref.data, debugName: 'result.data');
    freeNative(result, debugName: 'result');
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
    native_free(pointer.cast());
  }

  static String getFullViewKeyHexFromPrivateKeyData({
    required String privateKeyHex,
    required int index,
  }) {
    _checkInt32(index, 'index');
    return using((arena) {
      final fullViewKey = _requirePointer(
        native_getFullViewKeyFromPrivateKeyData(
          privateKeyHex.to32BytesFromHex().unsignedCharPointer(arena),
          index,
        ),
      );
      try {
        final size = arena<Int>();
        final serialized = _requirePointer(
          native_serializeFullViewKey(fullViewKey, size),
        );
        try {
          return serialized.cast<Uint8>().asTypedList(size.value).toHexString();
        } finally {
          freeNative(serialized, debugName: 'serialized');
        }
      } finally {
        _deleteFullViewKey(fullViewKey);
      }
    });
  }

  static Pointer<Void> _deserializeFullViewKey({
    required String fullViewKeyHex,
  }) {
    final bytes = fullViewKeyHex.to32OrMoreBytesFromHex();
    _checkInt32(bytes.length, 'fullViewKey.length');
    return using(
      (arena) => _requirePointer(
        native_deserializeFullViewKey(
          bytes.unsignedCharPointer(arena),
          bytes.length,
        ),
      ),
    );
  }

  /// Check whether the spark coin is ours and if so recover required data
  /// and encapsulate into a single object ([LibSparkCoin]).
  ///
  /// Returns a [LibSparkCoin] if the coin belongs to us, or null otherwise.
  static LibSparkCoin? identifyAndRecoverCoin(
    String serializedCoin, {
    required String privateKeyHex,
    required int index,
    required Uint8List context,
    bool isTestNet = false,
  }) {
    _checkInt32(index, 'index');
    _checkInt32(context.length, 'context.length');
    return using((arena) {
      final fullViewKey = _requirePointer(
        native_getFullViewKeyFromPrivateKeyData(
          privateKeyHex.to32BytesFromHex().unsignedCharPointer(arena),
          index,
        ),
      );
      try {
        return _recoverCoin(serializedCoin, fullViewKey, context, isTestNet);
      } finally {
        _deleteFullViewKey(fullViewKey);
      }
    });
  }

  /// Identifies and recovers a coin using a FullViewKey.
  ///
  /// Returns a [LibSparkCoin] if the coin belongs to us, or null otherwise.
  static LibSparkCoin? identifyAndRecoverCoinByFullViewKey({
    required String serializedCoin,
    required String fullViewKeyHex,
    required Uint8List context,
    bool isTestNet = false,
  }) {
    _checkInt32(context.length, 'context.length');
    final fullViewKey = _deserializeFullViewKey(fullViewKeyHex: fullViewKeyHex);
    try {
      return _recoverCoin(serializedCoin, fullViewKey, context, isTestNet);
    } finally {
      _deleteFullViewKey(fullViewKey);
    }
  }

  static LibSparkCoin? _recoverCoin(
    String serializedCoin,
    Pointer<Void> fullViewKey,
    Uint8List context,
    bool isTestNet,
  ) {
    return using((arena) {
      final coin = Uint8List.sublistView(base64Decode(serializedCoin), 0, 244);
      final result = native_idAndRecoverCoinByFullViewKey(
        coin.unsignedCharPointer(arena),
        coin.length,
        fullViewKey,
        context.unsignedCharPointer(arena),
        context.length,
        isTestNet ? 1 : 0,
      );
      if (result == nullptr) {
        // Drop the reason so a later call cannot report it as its own.
        _takeLastError();
        return null;
      }
      try {
        final type = switch (result.ref.type) {
          0 => LibSparkCoinType.mint,
          1 => LibSparkCoinType.spend,
          _ => throw Exception('Unknown coin type "${result.ref.type}" found.'),
        };
        return LibSparkCoin(
          type: type,
          nonceHex: result.ref.nonceHex.cast<Utf8>().toDartString(
            length: result.ref.nonceHexLength,
          ),
          address: result.ref.address.cast<Utf8>().toDartString(),
          value: BigInt.from(result.ref.value).toUnsigned(64),
          memo: utf8.decode(
            result.ref.memo.cast<Uint8>().asTypedList(result.ref.memoLength),
            allowMalformed: true,
          ),
          diversifier: BigInt.from(result.ref.diversifier).toUnsigned(64),
          encryptedDiversifier: result.ref.encryptedDiversifier.toUint8List(
            result.ref.encryptedDiversifierLength,
          ),
          serial: result.ref.serial.toUint8List(result.ref.serialLength),
          lTagHash: result.ref.lTagHash.cast<Utf8>().toDartString(),
        );
      } finally {
        freeNative(result.ref.address, debugName: 'result.address');
        freeNative(result.ref.memo, debugName: 'result.memo');
        freeNative(result.ref.lTagHash, debugName: 'result.lTagHash');
        freeNative(
          result.ref.encryptedDiversifier,
          debugName: 'result.encryptedDiversifier',
        );
        freeNative(result.ref.serial, debugName: 'result.serial');
        freeNative(result.ref.nonceHex, debugName: 'result.nonceHex');
        freeNative(result, debugName: 'result');
      }
    });
  }

  /// Deletes a FullViewKey.
  static void _deleteFullViewKey(Pointer<Void> fullViewKey) {
    DateTime? start;
    int? id;

    if (enableDebugLogging) {
      id = _id++;
      start = DateTime.now();
      String function = 'LibSpark._deleteFullViewKey';
      if (enableTraceLogging) {
        function += "(fullViewKey=$fullViewKey)";
      }

      Log.l(
        enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
        "BEGIN($id) $function",
        stackTrace: enableTraceLogging ? StackTrace.current : null,
      );
    }

    try {
      native_deleteFullViewKey(fullViewKey);
    } finally {
      if (enableDebugLogging) {
        Log.l(
          enableTraceLogging ? LoggingLevel.trace : LoggingLevel.debug,
          "END($id) LibSpark._deleteFullViewKey"
          " Duration=${DateTime.now().difference(start!)}",
        );
      }
    }
  }
}

extension on Pointer<UnsignedChar> {
  Uint8List toUint8List(int length) {
    return Uint8List.fromList(cast<Uint8>().asTypedList(length));
  }

  String toBase64(int length) {
    return base64.encode(cast<Uint8>().asTypedList(length));
  }
}

extension on Uint8List {
  Pointer<UnsignedChar> unsignedCharPointer(Allocator allocator) {
    final pointer = allocator<Uint8>(lengthInBytes == 0 ? 1 : lengthInBytes);
    pointer.asTypedList(lengthInBytes).setAll(0, this);
    return pointer.cast<UnsignedChar>();
  }
}
