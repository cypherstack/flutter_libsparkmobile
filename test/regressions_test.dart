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
  });
}
