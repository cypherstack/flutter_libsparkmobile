import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Generate a keyData from the mnemonic.
  Future<void> generateKeyData() async {
    final seed = bip39.mnemonicToSeed(
      mnemonicController.text,
      passphrase: '',
    );
    final root = coinlib.HDPrivateKey.fromSeed(seed);

    const purpose = 44; // BIP44.
    const coinType = 136; // Spark.
    // See https://github.com/firoorg/firo/blob/74769e8d329b08382fdcc367fc7d88b81521db06/src/wallet/wallet.cpp#L258.
    const account = 0; // Receiving.
    const chain = 6; // BIP44_SPARK_INDEX.
    final index = int.parse(indexController.text);
    final derivePath = "m/$purpose'/$coinType'/$account'/$chain/$index";

    final keys = root.derivePath(derivePath);

    // Cast Uint8List keys.privateKey.data to a hex string.
    final keyData = keys.privateKey.data.toHexString();

    setState(() {
      keyDataController.text = keyData;
    });
  }

  /// Derive an address from the keyData (mnemonic).
  Future<void> getAddress() async {
    try {
      final String keyDataHex = keyDataController.text;
      // Make sure keyDataHex is a valid hex string.
      if (keyDataHex.isEmpty ||
          !RegExp(r'^[0-9a-fA-F]+$').hasMatch(keyDataHex)) {
        throw 'Key data must be a valid hexadecimal string.';
      }

      // Convert the hex string to a list of bytes and pad to 32 bytes.
      final List<int> keyData = keyDataHex.toBytes();

      final index = int.parse(indexController.text);
      final diversifier = int.parse(diversifierController.text);

      String address = await _flutterLibsparkmobilePlugin.getAddress(
          keyData, index, diversifier);
      addressController.text = address;

      if (kDebugMode) {
        print('Address: $address');
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  String _platformVersion = 'Unknown';
  final FlutterLibsparkmobile _flutterLibsparkmobilePlugin;

  final mnemonicController = TextEditingController(
      text:
          'circle chunk sense green van control boat scare ketchup hidden depend attitude drama apple slogan robust fork exhaust screen easy response dumb fine creek');
  final keyDataController = TextEditingController(text: '0');
  final indexController =
      TextEditingController(text: '0'); // Default to index 0.
  final diversifierController =
      TextEditingController(text: '0'); // Default to diversifier 0.
  final addressController = TextEditingController();

  _MyAppState()
      : _flutterLibsparkmobilePlugin = FlutterLibsparkmobile(_loadLibrary());

  static DynamicLibrary _loadLibrary() {
    if (Platform.isLinux) {
      return DynamicLibrary.open('libsparkmobile.so');
    } else if (Platform.isAndroid) {
      // return DynamicLibrary.open('libsparkmobile.so');
    } else if (Platform.isIOS) {
      // return DynamicLibrary.open('libsparkmobile.dylib');
    } else if (Platform.isMacOS) {
      // return DynamicLibrary.open('libsparkmobile.dylib');
    } else if (Platform.isWindows) {
      // return DynamicLibrary.open('sparkmobile.dll');
    }
    throw UnsupportedError('This platform is not supported');
  }

  @override
  void initState() {
    super.initState();

    // Load coinlib.
    coinlib.loadCoinlib();

    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _flutterLibsparkmobilePlugin.getPlatformVersion() ??
              'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  bool isTestnet = true; // Default to testnet.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Spark Mobile Example App'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ElevatedButton(
              //   onPressed: generateMnemonic,
              //   child: const Text('Generate Mnemonic'),
              // ),
              // const SizedBox(height: 20),
              TextField(
                controller: mnemonicController,
                decoration: const InputDecoration(
                    labelText: 'Mnemonic Recovery Phrase'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: generateKeyData,
                child: const Text('Generate Key Data'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    // keyData takes the majority of the space
                    flex: 4,
                    child: TextField(
                      controller: keyDataController,
                      decoration: const InputDecoration(labelText: 'Key Data'),
                      keyboardType: TextInputType.number,
                      maxLength: 64,
                    ),
                  ),
                  const SizedBox(width: 8), // Spacing between inputs
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: TextField(
                        controller: indexController,
                        decoration: const InputDecoration(labelText: 'Index'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Spacing between inputs
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: TextField(
                        controller: diversifierController,
                        decoration:
                            const InputDecoration(labelText: 'Diversifier'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  // Checkbox(
                  //   value: isTestnet,
                  //   onChanged: (bool? newValue) {
                  //     setState(() {
                  //       isTestnet = newValue ?? true;
                  //     });
                  //   },
                  // ),
                  // const Text('Testnet'),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: getAddress,
                child: const Text('Get Address'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Spark Address'),
                readOnly: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convert a hex string to a list of bytes, padded to 32 bytes if necessary.
extension on String {
  List<int> toBytes() {
    // Pad the string to 64 characters with zeros if it's shorter.
    String hexString = padLeft(64, '0');

    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      var byteString = hexString.substring(i, i + 2);
      var byteValue = int.parse(byteString, radix: 16);
      bytes.add(byteValue);
    }
    return bytes;
  }
}

/// Convert a Uint8List to a hex string.
extension on Uint8List {
  String toHexString() {
    return map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
