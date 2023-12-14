import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';

class IdCoinView extends StatefulWidget {
  const IdCoinView({super.key});

  @override
  State<IdCoinView> createState() => _IdCoinViewState();
}

class _IdCoinViewState extends State<IdCoinView> {
  final privateKeyController = TextEditingController();
  final indexController = TextEditingController();
  final coinController = TextEditingController();
  final contextController = TextEditingController();

  bool checked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ID Coin"),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: privateKeyController,
                decoration: const InputDecoration(labelText: 'Private Key'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: indexController,
                decoration: const InputDecoration(labelText: 'Index'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: coinController,
                decoration: const InputDecoration(labelText: 'Coin'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: contextController,
                decoration: const InputDecoration(labelText: 'base64 context'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Checkbox(
                    value: checked,
                    onChanged: (value) {
                      if (value is bool) {
                        setState(() {
                          checked = value;
                        });
                      }
                    },
                  ),
                  const Text("Testnet"),
                  const Spacer(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                child: const Text("GO"),
                onPressed: () {
                  final coin = LibSpark.identifyAndRecoverCoin(
                    coinController.text,
                    privateKeyHex: privateKeyController.text,
                    index: int.parse(indexController.text),
                    context: base64Decode(contextController.text),
                    isTestNet: checked,
                  );

                  debugPrint(coin?.toString());
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
