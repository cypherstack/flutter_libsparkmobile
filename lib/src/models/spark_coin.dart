import 'dart:typed_data';

enum LibSparkCoinType {
  mint(0),
  spend(1);

  const LibSparkCoinType(this.value);
  final int value;
}

class LibSparkCoin {
  final LibSparkCoinType type;

  final Uint8List? nonce;

  final String? address;

  final BigInt? value;

  final String? memo;
  final Uint8List? serialContext;

  final BigInt? diversifier;
  final Uint8List? encryptedDiversifier;

  final Uint8List? serial;
  final Uint8List? tag;

  final String? lTagHash;

  LibSparkCoin({
    required this.type,
    this.nonce,
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

  LibSparkCoin copyWith({
    LibSparkCoinType? type,
    Uint8List? nonce,
    String? address,
    BigInt? value,
    String? memo,
    Uint8List? serialContext,
    BigInt? diversifier,
    Uint8List? encryptedDiversifier,
    Uint8List? serial,
    Uint8List? tag,
    String? lTagHash,
  }) {
    return LibSparkCoin(
      type: type ?? this.type,
      nonce: nonce ?? this.nonce,
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
    return 'LibSparkCoin('
        ', type: $type'
        ', k: $nonce'
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
