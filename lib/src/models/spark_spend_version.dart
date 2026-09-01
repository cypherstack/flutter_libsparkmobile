import 'dart:typed_data';

enum SparkSpendVersion {
  chaumV1(nativeValue: 1, transactionType: 9),
  chaumV2(nativeValue: 2, transactionType: 11);

  const SparkSpendVersion({
    required this.nativeValue,
    required this.transactionType,
  });

  static const int baseTransactionVersion = 3;
  final int nativeValue;
  final int transactionType;
  int get transactionVersion =>
      baseTransactionVersion | (transactionType << 16);

  static SparkSpendVersion forBlockHeight({
    required int nextBlockHeight,
    required int chaumV2ActivationHeight,
  }) {
    RangeError.checkNotNegative(nextBlockHeight, 'nextBlockHeight');
    RangeError.checkNotNegative(
      chaumV2ActivationHeight,
      'chaumV2ActivationHeight',
    );

    return nextBlockHeight >= chaumV2ActivationHeight ? chaumV2 : chaumV1;
  }

  Uint8List resolveExtensionCommitment(Uint8List? extensionCommitment) {
    final resolved = extensionCommitment ?? Uint8List(32);
    if (resolved.length != 32) {
      throw ArgumentError.value(
        resolved.length,
        'extensionCommitment.length',
        'must be 32',
      );
    }
    if (this == chaumV1 && resolved.any((byte) => byte != 0)) {
      throw ArgumentError.value(
        extensionCommitment,
        'extensionCommitment',
        'Chaum V1 cannot bind a non-zero extension commitment',
      );
    }

    return resolved;
  }
}

final class SparkNameProofInput {
  const SparkNameProofInput.chaumV1({required String scalarHex})
    : spendVersion = SparkSpendVersion.chaumV1,
      inputHex = scalarHex;

  const SparkNameProofInput.chaumV2({required String ownershipDigest})
    : spendVersion = SparkSpendVersion.chaumV2,
      inputHex = ownershipDigest;

  final SparkSpendVersion spendVersion;
  final String inputHex;
}
