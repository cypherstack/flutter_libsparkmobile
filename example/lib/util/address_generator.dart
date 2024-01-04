import 'dart:async';

import 'package:bip39/bip39.dart' as bip39;
import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_libsparkmobile/src/extensions.dart';

abstract class SparkAddressGenerator {
  /// Generate key data from a mnemonic.
  static Future<String> generateKeyData(
      String mnemonic, String derivePath) async {
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: '');
    final root = coinlib.HDPrivateKey.fromSeed(seed);

    // TODO validate derivePath.
    final keys = root.derivePath(derivePath);

    return keys.privateKey.data.toHexString();
  }

  /// Derive an address from the keyData (mnemonic).
  static Future<String> getAddress(
      String keyDataHex, int index, int diversifier, bool isTestnet) async {
    return await LibSpark.getAddress(
      privateKey: keyDataHex.to32BytesFromHex(),
      index: index,
      diversifier: diversifier,
      isTestNet: isTestnet,
    );
  }
}
