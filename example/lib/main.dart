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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: [
              Text('Running on: $_platformVersion\n'),
              // A button that, when pressed, generates a new Spark spend key.
              ElevatedButton(
                onPressed: () async {
                  final spendKey = await _flutterLibsparkmobilePlugin
                      .generateSpendKey()
                      .catchError((error) {
                    print(error);
                  });
                  print(spendKey);
                },
                child: const Text('Generate spend key'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
