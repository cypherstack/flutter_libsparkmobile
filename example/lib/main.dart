import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';

class SparkAddressGenerator {
  final FlutterLibsparkmobile _flutterLibsparkmobilePlugin;

  SparkAddressGenerator(this._flutterLibsparkmobilePlugin);

  /// Generate key data from a mnemonic.
  Future<String> generateKeyData(String mnemonic, String derivePath) async {
    final seed = bip39.mnemonicToSeed(mnemonic, passphrase: '');
    final root = coinlib.HDPrivateKey.fromSeed(seed);

    // TODO validate derivePath.
    final keys = root.derivePath(derivePath);

    return keys.privateKey.data.toHexString();
  }

  /// Derive an address from the keyData (mnemonic).
  Future<String> getAddress(
      String keyDataHex, int index, int diversifier, bool isTestnet) async {
    // Convert the hex string to a list of bytes and pad to 32 bytes.
    final List<int> keyData = keyDataHex.toBytes();

    return await _flutterLibsparkmobilePlugin.getAddress(
        keyData, index, diversifier, isTestnet);
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SparkAddressGenerator _addressGenerator;

  String _platformVersion = 'Unknown';
  final FlutterLibsparkmobile _flutterLibsparkmobilePlugin;

  final mnemonicController = TextEditingController(
      text:
          'jazz settle broccoli dove hurt deny leisure coffee ivory calm pact chicken flag spot nature gym afford cotton dinosaur young private flash core approve');

  final keyDataController = TextEditingController();
  final diversifierController =
      TextEditingController(text: '0'); // See Spark flow document.
  bool isTestnet = false; // Default to mainnet.

  final purposeController = TextEditingController(text: '44'); // BIP44.
  final coinTypeController = TextEditingController(text: '136'); // Mainnet.
  // 136 is mainnet, 1 is testnet.
  final accountController = TextEditingController(text: '0'); // Receiving.
  final chainController =
      TextEditingController(text: '6'); // BIP44_SPARK_INDEX.
  // BIP_44_SPARK_INDEX is 6.
  final indexController = TextEditingController(text: '1');

  final addressController = TextEditingController();

  // Define mnemonic strengths.
  final List<int> mnemonicStrengths = [
    128,
    256
  ]; // 128 bits for 12 words, 256 bits for 24 words.
  int currentStrength = 256; // 24 words by default.

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

    _addressGenerator = SparkAddressGenerator(_flutterLibsparkmobilePlugin);

    initPlatformState();

    SchedulerBinding.instance
        .addPostFrameCallback((_) => generateKeyDataAndGetAddress());
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

  Future<void> generateKeyData() async {
    // Construct derivePath string.
    final derivePath =
        "m/${purposeController.text}'/${coinTypeController.text}'/${accountController.text}'/${chainController.text}/${indexController.text}";

    final keyData = await _addressGenerator.generateKeyData(
        mnemonicController.text, derivePath);
    setState(() {
      keyDataController.text = keyData;
    });
  }

  Future<void> getAddress() async {
    final address = await _addressGenerator.getAddress(
      keyDataController.text,
      int.parse(indexController.text),
      int.parse(diversifierController.text),
      isTestnet,
    );
    setState(() {
      addressController.text = address;
    });
  }

  Future<void> generateKeyDataAndGetAddress() async {
    final purpose = int.parse(purposeController.text);
    final coinType = int.parse(coinTypeController.text);
    final account = int.parse(accountController.text);
    final chain = int.parse(chainController.text);
    final index = int.parse(indexController.text);

    // Construct derivePath string.
    final String derivePath = "m/$purpose'/$coinType'/$account'/$chain/$index";

    final keyData = await _addressGenerator.generateKeyData(
        mnemonicController.text, derivePath);

    setState(() {
      keyDataController.text = keyData;
    });

    await getAddress();
  }

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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: currentStrength,
                    items: mnemonicStrengths.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('${value == 128 ? 12 : 24} words'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        currentStrength = newValue!;
                      });
                    },
                  ),
                  const SizedBox(width: 8), // Spacing between inputs
                  ElevatedButton(
                    onPressed: () => setState(() {
                      mnemonicController.text =
                          bip39.generateMnemonic(strength: currentStrength);
                    }),
                    child: const Text('Generate Mnemonic'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                  const SizedBox(width: 8),
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
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isTestnet,
                            onChanged: (bool? newValue) {
                              setState(() {
                                isTestnet = newValue ?? true;
                                if (isTestnet) {
                                  coinTypeController.text = '1';
                                } else {
                                  coinTypeController.text = '136';
                                }
                              });
                            },
                          ),
                          const Text('Testnet'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildNumberInput(purposeController, 'Purpose'),
                  const SizedBox(width: 8),
                  _buildNumberInput(coinTypeController, 'Coin Type'),
                  const SizedBox(width: 8),
                  _buildNumberInput(accountController, 'Account'),
                  const SizedBox(width: 8),
                  _buildNumberInput(chainController, 'Chain'),
                  const SizedBox(width: 8),
                  _buildNumberInput(indexController, 'Index'),
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

  Widget _buildNumberInput(TextEditingController controller, String label) {
    return Expanded(
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
