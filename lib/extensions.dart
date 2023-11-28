import 'dart:typed_data';

extension Uint8ListExt on Uint8List {
  String toHexString() {
    return map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Convert a hex string to a list of bytes, padded to 32 bytes if necessary.
extension StringExt on String {
  Uint8List toBytes() {
    // Pad the string to 64 characters with zeros if it's shorter.
    String hexString = padLeft(64, '0');

    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      var byteString = hexString.substring(i, i + 2);
      var byteValue = int.parse(byteString, radix: 16);
      bytes.add(byteValue);
    }
    return Uint8List.fromList(bytes);
  }
}
