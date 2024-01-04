import 'dart:typed_data';

enum LibSparkCoinType {
  mint(0),
  spend(1);

  const LibSparkCoinType(this.value);
  final int value;
}

class LibSparkCoin {
  final LibSparkCoinType type;

  final int? id;
  final int? height;

  final bool? isUsed;

  final String? nonceHex;

  final String? address;

  final BigInt? value;

  final String? memo;

  final Uint8List? txHash;

  final Uint8List? serialContext;

  final BigInt? diversifier;
  final Uint8List? encryptedDiversifier;

  final Uint8List? serial;
  final Uint8List? tag;

  final String? lTagHash;

  final String? serializedCoin;

  LibSparkCoin({
    required this.type,
    this.id,
    this.height,
    this.isUsed,
    this.nonceHex,
    this.address,
    this.value,
    this.memo,
    this.txHash,
    this.serialContext,
    this.diversifier,
    this.encryptedDiversifier,
    this.serial,
    this.tag,
    this.lTagHash,
    this.serializedCoin,
  });

  LibSparkCoin copyWith({
    LibSparkCoinType? type,
    int? id,
    int? height,
    bool? isUsed,
    String? nonceHex,
    String? address,
    BigInt? value,
    String? memo,
    Uint8List? txHash,
    Uint8List? serialContext,
    BigInt? diversifier,
    Uint8List? encryptedDiversifier,
    Uint8List? serial,
    Uint8List? tag,
    String? lTagHash,
    String? serializedCoin,
  }) {
    return LibSparkCoin(
      type: type ?? this.type,
      id: id ?? this.id,
      height: height ?? this.height,
      isUsed: isUsed ?? this.isUsed,
      nonceHex: nonceHex ?? this.nonceHex,
      address: address ?? this.address,
      value: value ?? this.value,
      memo: memo ?? this.memo,
      txHash: txHash ?? this.txHash,
      serialContext: serialContext ?? this.serialContext,
      diversifier: diversifier ?? this.diversifier,
      encryptedDiversifier: encryptedDiversifier ?? this.encryptedDiversifier,
      serial: serial ?? this.serial,
      tag: tag ?? this.tag,
      lTagHash: lTagHash ?? this.lTagHash,
      serializedCoin: serializedCoin ?? this.serializedCoin,
    );
  }

  @override
  String toString() {
    return 'LibSparkCoin('
        ', type: $type'
        ', id: $id'
        ', height: $height'
        ', isUsed: $isUsed'
        ', k: $nonceHex'
        ', address: $address'
        ', value: $value'
        ', memo: $memo'
        ', txHash: $txHash'
        ', serialContext: $serialContext'
        ', diversifier: $diversifier'
        ', encryptedDiversifier: $encryptedDiversifier'
        ', serial: $serial'
        ', tag: $tag'
        ', lTagHash: $lTagHash'
        ', serializedCoin: $serializedCoin'
        ')';
  }
}
