import 'dart:typed_data';

extension Uint8ListExt on Uint8List {
  String toHexString() {
    return map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

final _hex = RegExp(r'^(?:[0-9a-fA-F]{2})*$');

/// Convert a hex string to a list of bytes, padded to 32 bytes if necessary.
extension StringExt on String {
  Uint8List to32BytesFromHex() {
    if (length > 64) {
      throw Exception("$this is too long for 32 bytes");
    }

    return to32OrMoreBytesFromHex();
  }

  Uint8List to32OrMoreBytesFromHex() {
    // Pad the string to 64 characters with zeros if it's shorter.
    final hexString = padLeft(64, '0');
    if (!_hex.hasMatch(hexString)) {
      throw const FormatException('Invalid hex string');
    }

    final bytes = Uint8List(hexString.length ~/ 2);
    for (int i = 0; i < hexString.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hexString.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
