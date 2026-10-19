import 'dart:typed_data';

extension Uint8ListExt on Uint8List {
  String toHexString() {
    return map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

final _hex = RegExp(r'^(?:[0-9a-fA-F]{2})*$');

/// Convert a hex string to a list of bytes, padded to 32 bytes if necessary.
///
/// Errors name the value as [name] but never include it, since it may be a
/// private key.
extension StringExt on String {
  Uint8List to32BytesFromHex([String name = 'value']) {
    if (length > 64) {
      throw Exception(
        '$name is $length hex characters; at most 64 are allowed',
      );
    }

    return to32OrMoreBytesFromHex(name);
  }

  Uint8List to32OrMoreBytesFromHex([String name = 'value']) {
    // Pad the string to 64 characters with zeros if it's shorter.
    final hexString = padLeft(64, '0');
    if (!_hex.hasMatch(hexString)) {
      throw FormatException('$name is not valid hex ($length characters)');
    }

    final bytes = Uint8List(hexString.length ~/ 2);
    for (int i = 0; i < hexString.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hexString.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
