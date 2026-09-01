import 'dart:typed_data';

import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_libsparkmobile/src/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Spark spend version', () {
    test('selects Chaum V2 at the activation boundary', () {
      expect(
        SparkSpendVersion.forBlockHeight(
          nextBlockHeight: 1370999,
          chaumV2ActivationHeight: 1371000,
        ),
        SparkSpendVersion.chaumV1,
      );
      expect(
        SparkSpendVersion.forBlockHeight(
          nextBlockHeight: 1371000,
          chaumV2ActivationHeight: 1371000,
        ),
        SparkSpendVersion.chaumV2,
      );
    });

    test('keeps native and outer transaction versions together', () {
      expect(SparkSpendVersion.chaumV1.nativeValue, 1);
      expect(SparkSpendVersion.chaumV1.transactionVersion, 3 | (9 << 16));
      expect(SparkSpendVersion.chaumV2.nativeValue, 2);
      expect(SparkSpendVersion.chaumV2.transactionVersion, 3 | (11 << 16));
    });

    test('defaults plain spends to a zero extension commitment', () {
      final commitment = SparkSpendVersion.chaumV2.resolveExtensionCommitment(
        null,
      );

      expect(commitment, hasLength(32));
      expect(commitment, everyElement(0));
    });

    test('rejects a non-zero Chaum V1 extension commitment', () {
      expect(
        () => SparkSpendVersion.chaumV1.resolveExtensionCommitment(
          Uint8List.fromList([1, ...List<int>.filled(31, 0)]),
        ),
        throwsArgumentError,
      );
    });

    test('keeps the Spark Name V1 scalar distinct from the V2 digest', () {
      const v1 = SparkNameProofInput.chaumV1(scalarHex: '01');
      const v2 = SparkNameProofInput.chaumV2(ownershipDigest: '02');

      expect(v1.spendVersion, SparkSpendVersion.chaumV1);
      expect(v1.inputHex, '01');
      expect(v2.spendVersion, SparkSpendVersion.chaumV2);
      expect(v2.inputHex, '02');
    });
  });

  test('Spark Names reject underscores', () {
    final pattern = RegExp(kNameRegexString);
    expect(pattern.hasMatch('NAME-FOR.TESTING'), isTrue);
    expect(pattern.hasMatch('NAME_FOR_TESTING'), isFalse);
  });

  test('Spark Name commitment rejects empty data', () {
    expect(
      () => LibSpark.getSparkNameCommitment(
        serializedSparkNameData: Uint8List(0),
      ),
      throwsArgumentError,
    );
  });

  test('mnemonic to address test', () async {
    // Generate key data from the mnemonic.
    //
    // The plugin integration test includes using the bip39 and coinlib packages
    // to generate the key data from the mnemonic.  Instead we will just use
    // a hard-coded key data hex string here in order to avoid unnecessary
    // dependencies.
    //
    // This keyData is derived from the mnemonic `jazz settle broccoli dove hurt
    // deny leisure coffee ivory calm pact chicken flag spot nature gym afford
    // cotton dinosaur young private flash core approve` at the firo-cli's
    // standard derivation path m/44'/136'/0'/6/1.
    const keyDataHex =
        'cb02b05c71a69080b083484f1cdf407677fac00ced6438df16925e2a29b4eebf';

    // Derive the address from the key data.
    final address = await LibSpark.getAddress(
      privateKey: keyDataHex.to32BytesFromHex(),
      index: 1,
      diversifier: 0,
      isTestNet: false,
    );

    // Define the expected address.
    const expectedAddress =
        'sm1shqukway59rq5nefgywyrrmmt8eswgjqdgnsdn4ysrsfl2rna60l2drelf6nfe0pamyxh3w8ypa7y35znhf4c6w44d7lw8xu3kjra4sg2v0zn508hawuul5596fm2h4e2csa9egk4ks3a';

    // Compare the derived address with the expected address.
    expect(address, expectedAddress);
  });
}
