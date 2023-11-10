import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_libsparkmobile_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Load coinlib for crypto operations.
  coinlib.loadCoinlib();

  // Initialize the plugin.
  final FlutterLibsparkmobile plugin = FlutterLibsparkmobile(_loadLibrary());
  final SparkAddressGenerator addressGenerator = SparkAddressGenerator(plugin);

  testWidgets('mnemonic to address test', (WidgetTester tester) async {
    // Define the mnemonic.
    const mnemonic =
        'jazz settle broccoli dove hurt deny leisure coffee ivory calm pact chicken flag spot nature gym afford cotton dinosaur young private flash core approve';

    // Construct derivePath string.
    const derivePath = "m/44'/136'/0'/6/1";

    // Generate key data from the mnemonic.
    final keyDataHex =
        await addressGenerator.generateKeyData(mnemonic, derivePath);

    // Derive the address from the key data.
    final address = await addressGenerator.getAddress(keyDataHex, 1, 0, false);

    // Define the expected address.
    const expectedAddress =
        'sm1shqukway59rq5nefgywyrrmmt8eswgjqdgnsdn4ysrsfl2rna60l2drelf6nfe0pamyxh3w8ypa7y35znhf4c6w44d7lw8xu3kjra4sg2v0zn508hawuul5596fm2h4e2csa9egk4ks3a';

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
