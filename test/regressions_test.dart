import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_libsparkmobile/src/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

const _privateKey =
    'cb02b05c71a69080b083484f1cdf407677fac00ced6438df16925e2a29b4eebf';
const _generatorX =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _generatorY =
    '483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8';

void _createSpend({
  required Uint8List txHash,
  List<({int setId, Uint8List blockHash})> blockHashes = const [],
}) {
  LibSpark.createSparkSendTransaction(
    privateKeyHex: _privateKey,
    recipients: [],
    privateRecipients: [],
    serializedCoins: [],
    allAnonymitySets: [],
    idAndBlockHashes: blockHashes,
    txHash: txHash,
    additionalTxSize: 0,
    spendVersion: SparkSpendVersion.chaumV2,
  );
}

void main() {
  group('Spend input validation', () {
    test('rejects transaction hashes that are not 32 bytes', () {
      for (final length in [0, 1, 31, 33, 64]) {
        expect(
          () => _createSpend(txHash: Uint8List(length)),
          throwsArgumentError,
        );
      }
    });

    test('rejects block hashes that are not 32 bytes', () {
      for (final length in [0, 1, 31, 33, 64]) {
        expect(
          () => _createSpend(
            txHash: Uint8List(32),
            blockHashes: [(setId: 1, blockHash: Uint8List(length))],
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('Fee estimation input validation', () {
    test('rejects negative group IDs like negative set IDs', () {
      for (final groupId in [-1, -0x80000000]) {
        expect(
          () => LibSpark.estimateSparkFee(
            privateKeyHex: _privateKey,
            sendAmount: 1,
            subtractFeeFromAmount: false,
            serializedCoins: [
              (
                serializedCoin: base64Encode(Uint8List(244)),
                serializedCoinContext: base64Encode(Uint8List(0)),
                groupId: groupId,
                height: 1,
              ),
            ],
            privateRecipientsCount: 1,
            utxoNum: 0,
            additionalTxSize: 0,
            spendVersion: SparkSpendVersion.chaumV2,
          ),
          throwsRangeError,
        );
      }
    });
  });

  group('Tag hashing', () {
    test('checks every decoded tag length', () {
      for (final length in [0, 1, 33, 35, 68]) {
        expect(
          () =>
              LibSpark.hashTags(base64Tags: [base64Encode(Uint8List(length))]),
          throwsArgumentError,
        );
      }
      expect(
        () => LibSpark.hashTags(
          base64Tags: [
            base64Encode(Uint8List(33)),
            base64Encode(Uint8List(35)),
          ],
        ),
        throwsArgumentError,
      );
      expect(LibSpark.hashTags(base64Tags: []), isEmpty);
    });

    test('reports malformed tags and coordinates as Dart errors', () {
      expect(() => LibSpark.hashTag('invalid', 'invalid'), throwsException);
      expect(
        () => LibSpark.hashTags(base64Tags: [base64Encode(Uint8List(34))]),
        throwsException,
      );
    });

    test('batch hashing agrees with coordinate hashing', () {
      final bytes = Uint8List.fromList([
        ..._generatorX.to32BytesFromHex(),
        0,
        0,
      ]);
      final expected = LibSpark.hashTag(_generatorX, _generatorY);
      expect(
        LibSpark.hashTags(
          base64Tags: [base64Encode(bytes), base64Encode(bytes)],
        ),
        [expected, expected],
      );
    });
  });

  group('Full view keys', () {
    late String fullViewKey;

    setUpAll(() {
      fullViewKey = LibSpark.getFullViewKeyHexFromPrivateKeyData(
        privateKeyHex: _privateKey,
        index: 1,
      );
    });

    test('derives the same addresses as the private key', () async {
      for (final diversifier in [0, 7, 0x7fffffff]) {
        for (final isTestNet in [false, true]) {
          final address = await LibSpark.getAddress(
            privateKey: _privateKey.to32BytesFromHex(),
            index: 1,
            diversifier: diversifier,
            isTestNet: isTestNet,
          );
          expect(
            await LibSpark.getAddressFromFullViewKey(
              fullViewKeyHex: fullViewKey,
              index: 1,
              diversifier: diversifier,
              isTestNet: isTestNet,
            ),
            address,
          );
        }
      }
    });

    test('rejects malformed keys', () async {
      for (final invalid in [
        '',
        'gg',
        fullViewKey.substring(2),
        '${fullViewKey}00',
        'ff' * (fullViewKey.length ~/ 2),
      ]) {
        await expectLater(
          LibSpark.getAddressFromFullViewKey(
            fullViewKeyHex: invalid,
            index: 1,
            diversifier: 0,
          ),
          throwsA(anyOf(isA<ArgumentError>(), isA<Exception>())),
        );
      }
    });

    test('rejects indices and diversifiers outside signed int32', () async {
      for (final value in [-1, 0x80000000, 0x100000001]) {
        for (final index in [true, false]) {
          await expectLater(
            LibSpark.getAddress(
              privateKey: _privateKey.to32BytesFromHex(),
              index: index ? value : 1,
              diversifier: index ? 0 : value,
            ),
            value < 0 ? throwsException : throwsRangeError,
          );
          await expectLater(
            LibSpark.getAddressFromFullViewKey(
              fullViewKeyHex: fullViewKey,
              index: index ? value : 1,
              diversifier: index ? 0 : value,
            ),
            throwsRangeError,
          );
        }
        expect(
          () => LibSpark.getFullViewKeyHexFromPrivateKeyData(
            privateKeyHex: _privateKey,
            index: value,
          ),
          throwsRangeError,
        );
      }
    });

    test(
      'preserves Unicode and embedded NUL in recovered mint memos',
      () async {
        final address = await LibSpark.getAddressFromFullViewKey(
          fullViewKeyHex: fullViewKey,
          index: 1,
          diversifier: 7,
        );
        final context = LibSpark.serializeMintContext(inputs: [('01', 0)]);
        for (final memo in ['', 'é', '🦊', 'λhello', 'before\u0000after']) {
          final mint = LibSpark.createSparkMintRecipients(
            outputs: [(sparkAddress: address, value: 100000, memo: memo)],
            serialContext: context,
            generate: true,
          ).single;
          final coin = LibSpark.identifyAndRecoverCoinByFullViewKey(
            serializedCoin: base64Encode(mint.scriptPubKey.sublist(1)),
            fullViewKeyHex: fullViewKey,
            context: context,
          );
          expect(coin, isNotNull);
          expect(coin!.memo, memo);
          expect(coin.value, BigInt.from(100000));
          expect(coin.diversifier, BigInt.from(7));
          expect(coin.address, address);
        }
      },
    );

    test('recovers arbitrary memo bytes and unsigned diversifiers', () {
      const serializedCoin =
          'AQHiMWMbOkZUYra2YgPR6zlbpTRsTiEO2h5u14q3hh9hAQA87JhV2gEG0KdLImBgfP/olSJr7Sw0elGrr7x52i25bAEArUsP/GJEIid3EAcG1q0JaCM7v6KqLmPSfjWL/gj+258BAFokEjKkKOtsN+pvBwzDZ3wQ3me6xT1Pjmb5VN7MVQ6Knsn6CQb33jv5okWIs2t+InRYODCwFw+Lsv6ATpY+nzx/n/Vr2N8n0sQZWYBn89cwkUZS+8d5Gi6VT+kQMKy5tPxEi1hwg3QUXxFZQyB/FRTeZwrL5doyrMgZRqFP+DDR4pncEM98CU68TSvyPg==';
      final coin = LibSpark.identifyAndRecoverCoinByFullViewKey(
        serializedCoin: serializedCoin,
        fullViewKeyHex: fullViewKey,
        context: Uint8List.fromList([1, 2, 3]),
      );
      expect(coin, isNotNull);
      expect(coin!.memo, '\ufffd\u0000after');
      expect(coin.diversifier, BigInt.parse('18446744073709551615'));
      expect(coin.value, BigInt.from(100000000));
    });

    test('preserves Unicode and embedded NUL in private spend memos', () async {
      final address = await LibSpark.getAddressFromFullViewKey(
        fullViewKeyHex: fullViewKey,
        index: 1,
        diversifier: 7,
      );
      final mintContext = LibSpark.serializeMintContext(inputs: [('01', 0)]);
      final mint = LibSpark.createSparkMintRecipients(
        outputs: [(sparkAddress: address, value: 100000000, memo: '')],
        serialContext: mintContext,
        generate: true,
      ).single;
      final serializedCoin = base64Encode(mint.scriptPubKey.sublist(1, 245));
      final serializedCoins = [
        (
          serializedCoin: serializedCoin,
          serializedCoinContext: base64Encode(mintContext),
          groupId: 1,
          height: 1,
        ),
      ];
      final txHash = Uint8List(32);
      const memo = 'é🦊\u0000after';
      final estimatedFee = LibSpark.estimateSparkFee(
        privateKeyHex: _privateKey,
        sendAmount: 10000000,
        subtractFeeFromAmount: false,
        serializedCoins: serializedCoins,
        privateRecipientsCount: 1,
        utxoNum: 0,
        additionalTxSize: 0,
        spendVersion: SparkSpendVersion.chaumV2,
      );
      final spend = LibSpark.createSparkSendTransaction(
        privateKeyHex: _privateKey,
        recipients: [],
        privateRecipients: [
          (
            sparkAddress: address,
            amount: 10000000,
            subtractFeeFromAmount: false,
            memo: memo,
          ),
        ],
        serializedCoins: serializedCoins,
        allAnonymitySets: [
          (
            setId: 1,
            setHash: base64Encode(Uint8List(32)),
            set: [(serializedCoin: serializedCoin, txHash: '00' * 32)],
          ),
        ],
        idAndBlockHashes: [(setId: 1, blockHash: Uint8List(32))],
        txHash: txHash,
        additionalTxSize: 0,
        spendVersion: SparkSpendVersion.chaumV2,
      );
      expect(spend.serializedSpendPayload.sublist(0, 3), [2, 1, 2]);
      final spendContext = Uint8List.fromList([
        1,
        ...spend.serializedSpendPayload.sublist(160, 194),
      ]);
      final recovered = spend.outputScripts.map(
        (script) => LibSpark.identifyAndRecoverCoinByFullViewKey(
          serializedCoin: base64Encode(script.sublist(1)),
          fullViewKeyHex: fullViewKey,
          context: spendContext,
        ),
      );
      final recipient = recovered.singleWhere((coin) => coin?.memo == memo)!;
      expect(recipient.value, BigInt.from(10000000));
      expect(spend.serializedSpendPayload, isNotEmpty);
      expect(spend.fee, greaterThan(0));
      expect(spend.fee, estimatedFee);
    });

    test('rejects invalid mint addresses without terminating the process', () {
      expect(
        () => LibSpark.createSparkMintRecipients(
          outputs: [(sparkAddress: 'invalid', value: 100000, memo: '')],
          serialContext: Uint8List.fromList([1, 2, 3]),
        ),
        throwsException,
      );
    });

    test('rejects address suffixes hidden by NUL', () async {
      final address = await LibSpark.getAddressFromFullViewKey(
        fullViewKeyHex: fullViewKey,
        index: 1,
        diversifier: 0,
      );
      expect(
        LibSpark.validateAddress(address: address, isTestNet: false),
        isTrue,
      );
      expect(
        LibSpark.validateAddress(
          address: '$address\u0000suffix',
          isTestNet: false,
        ),
        isFalse,
      );
      expect(
        () => LibSpark.createSparkMintRecipients(
          outputs: [
            (sparkAddress: '$address\u0000suffix', value: 100000, memo: ''),
          ],
          serialContext: Uint8List.fromList([1, 2, 3]),
        ),
        throwsArgumentError,
      );
    });

    test('rejects NUL in lengthless name inputs', () {
      for (final name in [true, false]) {
        expect(
          () => LibSpark.createSparkNameScript(
            sparkNameValidityBlocks: 1,
            name: name ? 'name\u0000suffix' : 'name',
            additionalInfo: name ? '' : 'info\u0000suffix',
            proofInput: const SparkNameProofInput.chaumV1(scalarHex: '01'),
            privateKeyHex: _privateKey,
            spendKeyIndex: 1,
            diversifier: 0,
            isTestNet: false,
            hashFailSafe: 1,
            ignoreProof: true,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('Logging', () {
    late Set<LoggingLevel> previousLevels;
    late List<(LoggingLevel, Object?)> events;
    final previousCallback = Log.onLog;

    setUp(() {
      previousLevels = Log.levels;
      events = [];
      Log.onLog = (level, value, {error, stackTrace, required time}) {
        events.add((level, value));
      };
    });

    tearDown(() {
      Log.levels = previousLevels;
      Log.onLog = previousCallback;
    });

    test('delivers only enabled levels', () {
      Log.levels = {LoggingLevel.warning};
      Log.d('hidden');
      Log.w('visible');
      expect(events, [(LoggingLevel.warning, 'visible')]);
    });

    test('traces operations when debug is disabled', () async {
      Log.levels = {LoggingLevel.trace};
      await LibSpark.getAddress(
        privateKey: _privateKey.to32BytesFromHex(),
        index: 1,
        diversifier: 0,
      );
      expect(events, isNotEmpty);
      expect(events.map((event) => event.$1), everyElement(LoggingLevel.trace));
      final messages = events.map((event) => event.$2.toString());
      expect(messages.any((message) => message.startsWith('BEGIN(')), isTrue);
      expect(messages.any((message) => message.startsWith('END(')), isTrue);
    });
  });
}
