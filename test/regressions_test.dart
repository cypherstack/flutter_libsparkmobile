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
const _fieldPrime =
    'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f';

Matcher throwsExceptionContaining(String fragment) => throwsA(
  isA<Exception>().having((e) => e.toString(), 'message', contains(fragment)),
);

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

    test('rejects off-curve coordinates, including compressed tag aliases', () {
      for (final (x, y) in [
        ('0', '0'),
        (_generatorX, '0'),
        (_generatorX, '1'),
        (_generatorX, '2'),
      ]) {
        expect(() => LibSpark.hashTag(x, y), throwsException);
      }
    });

    test('rejects negative and out-of-field coordinates', () {
      const fieldPrime =
          'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f';
      const pointAtOneY =
          '4218f20ae6c646b363db68605822fb14264ca8d2587fdd6fbc750d587e76a7ee';
      expect(LibSpark.hashTag('1', pointAtOneY), isNotEmpty);
      for (final coordinate in [
        '-0',
        '-1',
        '-$_generatorX',
        fieldPrime,
        fieldPrime.toUpperCase(),
        '00$fieldPrime',
        'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc30',
        'f' * 64,
        '1' * 65,
      ]) {
        expect(
          () => LibSpark.hashTag(coordinate, pointAtOneY),
          throwsException,
        );
        expect(
          () => LibSpark.hashTag(_generatorX, coordinate),
          throwsException,
        );
      }
    });

    test(
      'preserves valid hashes for uppercase and leading-zero coordinates',
      () {
        const expected =
            '19b567e8409caeadc4b177ce20d9dddaa3444decdba75d72df4d7aa6d5767181';
        for (final (x, y) in [
          (_generatorX, _generatorY),
          (_generatorX.toUpperCase(), _generatorY.toUpperCase()),
          ('00$_generatorX', '00$_generatorY'),
        ]) {
          expect(LibSpark.hashTag(x, y), expected);
        }
      },
    );

    test('accepts a valid point near the field boundary', () {
      const x =
          'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2c';
      const y =
          '0e994b14ea72f8c3eb95c71ef692575e775058332d7e52d0995cf8038871b67d';
      final expected = LibSpark.hashTag(x, y);
      expect(LibSpark.hashTag(x.toUpperCase(), y.toUpperCase()), expected);
      expect(LibSpark.hashTag('00$x', '00$y'), expected);
    });

    test('rejects non-canonical batch tags like coordinate hashing', () {
      final x = _generatorX.to32BytesFromHex();
      final p = _fieldPrime.to32BytesFromHex();
      for (final tag in [
        [...x, 0, 1],
        [...x, 1, 1],
        [...x, 2, 0],
        [...p, 0, 0],
        [...p, 1, 0],
      ]) {
        expect(
          () => LibSpark.hashTags(
            base64Tags: [base64Encode(Uint8List.fromList(tag))],
          ),
          throwsExceptionContaining('canonical'),
        );
      }
    });

    test('batch hashing honours the oddness byte', () {
      final negatedY =
          (BigInt.parse(_fieldPrime, radix: 16) -
                  BigInt.parse(_generatorY, radix: 16))
              .toRadixString(16);
      final tag = Uint8List.fromList([..._generatorX.to32BytesFromHex(), 1, 0]);
      final hash = LibSpark.hashTags(base64Tags: [base64Encode(tag)]).single;
      expect(hash, LibSpark.hashTag(_generatorX, negatedY));
      expect(hash, isNot(LibSpark.hashTag(_generatorX, _generatorY)));
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

  group('Hex parsing', () {
    test('rejects signs, whitespace, and other non-hex characters', () {
      final prefix = _privateKey.substring(2);
      for (final invalid in ['$prefix-f', '$prefix+f', '$prefix f', 'gg']) {
        expect(
          () => LibSpark.getFullViewKeyHexFromPrivateKeyData(
            privateKeyHex: invalid,
            index: 1,
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects odd-length hex longer than 32 bytes', () async {
      final fullViewKey = LibSpark.getFullViewKeyHexFromPrivateKeyData(
        privateKeyHex: _privateKey,
        index: 1,
      );
      await expectLater(
        LibSpark.getAddressFromFullViewKey(
          fullViewKeyHex: '${fullViewKey}0',
          index: 1,
          diversifier: 0,
        ),
        throwsFormatException,
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
          final fromPrivateKey = LibSpark.identifyAndRecoverCoin(
            base64Encode(mint.scriptPubKey.sublist(1)),
            privateKeyHex: _privateKey,
            index: 1,
            context: context,
          );
          expect(fromPrivateKey, isNotNull);
          expect(fromPrivateKey!.memo, coin.memo);
          expect(fromPrivateKey.value, coin.value);
          expect(fromPrivateKey.diversifier, coin.diversifier);
          expect(fromPrivateKey.address, coin.address);
          expect(fromPrivateKey.serial, coin.serial);
          expect(fromPrivateKey.lTagHash, coin.lTagHash);
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

    test('both recovery methods reject foreign and malformed coins', () async {
      final address = await LibSpark.getAddressFromFullViewKey(
        fullViewKeyHex: fullViewKey,
        index: 1,
        diversifier: 7,
      );
      final context = LibSpark.serializeMintContext(inputs: [('01', 0)]);
      final mint = LibSpark.createSparkMintRecipients(
        outputs: [(sparkAddress: address, value: 100000, memo: '')],
        serialContext: context,
        generate: true,
      ).single;
      final foreignKey = LibSpark.getFullViewKeyHexFromPrivateKeyData(
        privateKeyHex: _privateKey,
        index: 2,
      );
      for (final serializedCoin in [
        base64Encode(mint.scriptPubKey.sublist(1)),
        base64Encode(Uint8List(244)),
      ]) {
        expect(
          LibSpark.identifyAndRecoverCoin(
            serializedCoin,
            privateKeyHex: _privateKey,
            index: 2,
            context: context,
          ),
          isNull,
        );
        expect(
          LibSpark.identifyAndRecoverCoinByFullViewKey(
            serializedCoin: serializedCoin,
            fullViewKeyHex: foreignKey,
            context: context,
          ),
          isNull,
        );
      }
    });

    test('treats short coins as foreign instead of throwing', () {
      for (final length in [0, 1, 243]) {
        expect(
          LibSpark.identifyAndRecoverCoinByFullViewKey(
            serializedCoin: base64Encode(Uint8List(length)),
            fullViewKeyHex: fullViewKey,
            context: Uint8List(0),
          ),
          isNull,
        );
      }
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

  group('Native errors', () {
    test('carry the native reason for a rejected mint address', () {
      expect(
        () => LibSpark.createSparkMintRecipients(
          outputs: [(sparkAddress: 'invalid', value: 100000, memo: '')],
          serialContext: Uint8List.fromList([1, 2, 3]),
        ),
        throwsExceptionContaining('Bad address encoding'),
      );
    });

    test('carry the reason for each kind of rejected tag', () {
      expect(
        () => LibSpark.hashTag('invalid', 'invalid'),
        throwsExceptionContaining('field prime'),
      );
      expect(
        () => LibSpark.hashTag(_generatorX, '0'),
        throwsExceptionContaining('point on the curve'),
      );
      expect(
        () => LibSpark.hashTags(base64Tags: [base64Encode(Uint8List(34))]),
        throwsExceptionContaining('deserialize failed'),
      );
    });

    test('carry the reason for a full view key of the wrong length', () async {
      await expectLater(
        LibSpark.getAddressFromFullViewKey(
          fullViewKeyHex: '00',
          index: 1,
          diversifier: 0,
        ),
        throwsExceptionContaining('unexpected length'),
      );
    });

    test('report the latest failure after intervening calls', () {
      expect(() => LibSpark.hashTag('invalid', 'invalid'), throwsException);
      expect(LibSpark.hashTag(_generatorX, _generatorY), isNotEmpty);
      expect(
        () => LibSpark.hashTag(_generatorX, '0'),
        throwsExceptionContaining('point on the curve'),
      );
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
