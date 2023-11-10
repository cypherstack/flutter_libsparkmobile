import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Load coinlib for crypto operations.
  coinlib.loadCoinlib();

  testWidgets('mnemonic to address test', (WidgetTester tester) async {
    // Initialize the plugin.
    final FlutterLibsparkmobile plugin = FlutterLibsparkmobile(_loadLibrary());

    // Define the mnemonic.
    const mnemonic =
        'circle chunk sense green van control boat scare ketchup hidden depend attitude drama apple slogan robust fork exhaust screen easy response dumb fine creek';

    // Generate key data from the mnemonic.
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: '');
    final root = coinlib.HDPrivateKey.fromSeed(seed);

    const purpose = 44; // BIP44.
    const coinType = 136; // Spark.
    const account = 0; // Receiving.
    const chain = 6; // BIP44_SPARK_INDEX.
    const index = 0; // The index for the address.
    const derivePath = "m/$purpose'/$coinType'/$account'/$chain/$index";

    final keys = root.derivePath(derivePath);

    // Convert Uint8List keys.privateKey.data to a hex string.
    final keyDataHex = keys.privateKey.data.toHexString();

    // Derive the address from the key data.
    final address = await plugin.getAddress(
      keyDataHex.toBytes(), // Convert hex string to list of bytes.
      index,
      0, // Diversifier.
      true, // Testnet.
    );

    // Define the expected address.
    const expectedAddress =
        'st1dycx6xhtmmk906jqywqrmqm3mk57sex4cuy8ar2jeecqc3ug7wu9dh8pu864avldkr6cef735ktw39gwlv4pq5h9egyqluhtluf06c0v0qeejqtf7cfafjdt6v4hftvh5xwxu6cldgjc5';

    // Compare the derived address with the expected address.
    expect(address, expectedAddress);
  });
}

/// Load the native library.
ffi.DynamicLibrary _loadLibrary() {
  if (Platform.isLinux) {
    return ffi.DynamicLibrary.open('libsparkmobile.so');
  } else if (Platform.isAndroid) {
    return ffi.DynamicLibrary.open('libsparkmobile.so');
  } else if (Platform.isIOS) {
    return ffi.DynamicLibrary.open('libsparkmobile.dylib');
  } else if (Platform.isMacOS) {
    return ffi.DynamicLibrary.open('libsparkmobile.dylib');
  } else if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('sparkmobile.dll');
  }
  throw UnsupportedError('This platform is not supported');
}

/// Extension to convert hex string to list of bytes.
extension on String {
  Uint8List toBytes() {
    List<int> bytes = [];
    for (int i = 0; i < length; i += 2) {
      var byteString = substring(i, i + 2);
      var byteValue = int.parse(byteString, radix: 16);
      bytes.add(byteValue);
    }
    return Uint8List.fromList(bytes);
  }
}

/// Extension to convert Uint8List to a hex string.
extension on Uint8List {
  String toHexString() {
    return map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
