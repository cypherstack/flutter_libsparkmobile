import 'dart:typed_data';

enum SparkCoinType {
  mint(0),
  spend(1);

  const SparkCoinType(this.value);
  final int value;
}

class SparkCoin {
  final SparkCoinType type;

  final Uint8List? k; // TODO: proper name (not single char!!) is this nonce???

  final String? address;

  final BigInt? value;

  final String? memo;
  final Uint8List? serialContext;

  final BigInt? diversifier;
  final Uint8List? encryptedDiversifier;

  final Uint8List? serial;
  final Uint8List? tag;

  final Uint8List? lTagHash;

  SparkCoin({
    required this.type,
    this.k,
    this.address,
    this.value,
    this.memo,
    this.serialContext,
    this.diversifier,
    this.encryptedDiversifier,
    this.serial,
    this.tag,
    this.lTagHash,
  });

  SparkCoin copyWith({
    SparkCoinType? type,
    Uint8List? k,
    String? address,
    BigInt? value,
    String? memo,
    Uint8List? serialContext,
    BigInt? diversifier,
    Uint8List? encryptedDiversifier,
    Uint8List? serial,
    Uint8List? tag,
    Uint8List? lTagHash,
  }) {
    return SparkCoin(
      type: type ?? this.type,
      k: k ?? this.k,
      address: address ?? this.address,
      value: value ?? this.value,
      memo: memo ?? this.memo,
      serialContext: serialContext ?? this.serialContext,
      diversifier: diversifier ?? this.diversifier,
      encryptedDiversifier: encryptedDiversifier ?? this.encryptedDiversifier,
      serial: serial ?? this.serial,
      tag: tag ?? this.tag,
      lTagHash: lTagHash ?? this.lTagHash,
    );
  }

  @override
  String toString() {
    return 'SparkCoin('
        ', type: $type'
        ', k: $k'
        ', address: $address'
        ', value: $value'
        ', memo: $memo'
        ', serialContext: $serialContext'
        ', diversifier: $diversifier'
        ', encryptedDiversifier: $encryptedDiversifier'
        ', serial: $serial'
        ', tag: $tag'
        ', lTagHash: $lTagHash'
        ')';
  }
}
