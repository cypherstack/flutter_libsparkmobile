import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_libsparkmobile/src/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

const _privateKey =
    'cb02b05c71a69080b083484f1cdf407677fac00ced6438df16925e2a29b4eebf';
void main() {
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

    test('recovers arbitrary memo bytes', () {
      const serializedCoin =
          'AQHiMWMbOkZUYra2YgPR6zlbpTRsTiEO2h5u14q3hh9hAQA87JhV2gEG0KdLImBgfP/olSJr7Sw0elGrr7x52i25bAEArUsP/GJEIid3EAcG1q0JaCM7v6KqLmPSfjWL/gj+258BAFokEjKkKOtsN+pvBwzDZ3wQ3me6xT1Pjmb5VN7MVQ6Knsn6CQb33jv5okWIs2t+InRYODCwFw+Lsv6ATpY+nzx/n/Vr2N8n0sQZWYBn89cwkUZS+8d5Gi6VT+kQMKy5tPxEi1hwg3QUXxFZQyB/FRTeZwrL5doyrMgZRqFP+DDR4pncEM98CU68TSvyPg==';
      final coin = LibSpark.identifyAndRecoverCoinByFullViewKey(
        serializedCoin: serializedCoin,
        fullViewKeyHex: fullViewKey,
        context: Uint8List.fromList([1, 2, 3]),
      );
      expect(coin, isNotNull);
      expect(coin!.memo, '\ufffd\u0000after');
      expect(coin.value, BigInt.from(100000000));
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
}
