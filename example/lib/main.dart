import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart'; // For kDebugMode.
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

  Future<void> _generateSpendKey() async {
    String spendKey = await _flutterLibsparkmobilePlugin
        .generateSpendKey()
        .catchError((error) {
      if (kDebugMode) {
        print(error);
      }
    });

    // Update the TextInput with the generated key.
    spendKeyController.text = spendKey;
    if (kDebugMode) {
      print('spendKey: $spendKey');
    }

    _createFullViewKey();
  }

  Future<void> _createFullViewKey() async {
    String fullViewKey = await _flutterLibsparkmobilePlugin
        .createFullViewKey(spendKeyController.text)
        .catchError((error) {
      if (kDebugMode) {
        print(error);
      }
    });

    // Update the TextInput with the generated key.
    fullViewKeyController.text = fullViewKey;
    if (kDebugMode) {
      print('fullViewKey: $fullViewKey');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Running on: $_platformVersion\n'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      // Wrap the TextField with an Expanded widget
                      child: TextField(
                        controller: spendKeyController,
                        decoration:
                            const InputDecoration(labelText: 'Spend Key (r)'),
                      ),
                    ),
                    // Button for generating a new Spark spend key.
                    ElevatedButton(
                      onPressed: _generateSpendKey,
                      child: const Text('Generate spend key'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      // Wrap the TextField with an Expanded widget
                      child: TextField(
                        controller: fullViewKeyController,
                        decoration:
                            const InputDecoration(labelText: 'Full View Key'),
                      ),
                    ),
                    // Button for generating a new Spark spend key.
                    ElevatedButton(
                      onPressed: _createFullViewKey,
                      child: const Text('Derive full view key'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: incomingViewKeyController,
                  decoration:
                      const InputDecoration(labelText: 'Incoming View Key'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
