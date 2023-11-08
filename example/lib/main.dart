import 'dart:async';
import 'dart:ffi';
import 'dart:io';

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
  String _platformVersion = 'Unknown';
  final FlutterLibsparkmobile _flutterLibsparkmobilePlugin;

  // TextEditingControllers for example app inputs.
  final spendKeyController = TextEditingController();
  final fullViewKeyController = TextEditingController();
  final incomingViewKeyController = TextEditingController();
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
    // Optionally throw an error or handle other platforms
    throw UnsupportedError('This platform is not supported');
  }

  @override
  void initState() {
    super.initState();
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

  final _mnemonicController = TextEditingController();
  final _keyDataController = TextEditingController();
  final _indexController =
      TextEditingController(text: '0'); // Default to index 0
  final _diversifierController =
      TextEditingController(text: '0'); // Default to diversifier 0
  final _addressController = TextEditingController();

  bool _isTestnet = true; // Default to testnet

  // This dummy function is assumed to interact with the native code to generate keyData from the mnemonic.
  Future<void> _generateKeyData() async {
    // Simulate generating keyData from the mnemonic.
    // You would call your native code here.
    const keyData = '00000000000000000000000000000000';
    setState(() {
      _keyDataController.text = keyData;
    });
  }

  Future<void> _getAddress() async {
    try {
      final keyData = _keyDataController.text;
      final index = int.parse(_indexController.text);
      final diversifier = int.parse(_diversifierController.text);

      String address = await _flutterLibsparkmobilePlugin.getAddress(
          keyData, index, diversifier);
      addressController.text = address;
    } catch (e) {
      // Handle the error, e.g., show an alert or a snackbar
      print('Error getting address: $e');
    }
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
              TextField(
                controller: _mnemonicController,
                decoration: const InputDecoration(
                    labelText: 'Mnemonic Recovery Phrase'),
              ),
              ElevatedButton(
                onPressed: _generateKeyData,
                child: const Text('Generate Key Data'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _keyDataController,
                decoration: const InputDecoration(labelText: 'Key Data'),
              ),
              TextField(
                controller: _indexController,
                decoration: const InputDecoration(labelText: 'Index'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _diversifierController,
                decoration: const InputDecoration(labelText: 'Diversifier'),
                keyboardType: TextInputType.number,
              ),
              // Row(
              //   children: [
              //     Checkbox(
              //       value: _isTestnet,
              //       onChanged: (bool? newValue) {
              //         setState(() {
              //           _isTestnet = newValue ?? true;
              //         });
              //       },
              //     ),
              //     const Text('Testnet'),
              //   ],
              // ),
              ElevatedButton(
                onPressed: _getAddress,
                child: const Text('Get Address'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _addressController,
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
