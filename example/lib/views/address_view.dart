import 'dart:async';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libsparkmobile_example/util/address_generator.dart';

class AddressView extends StatefulWidget {
  const AddressView({super.key});

  @override
  State<AddressView> createState() => _AddressViewState();
}

class _AddressViewState extends State<AddressView> {
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

  Future<void> generateKeyData() async {
    // Construct derivePath string.
    final derivePath =
        "m/${purposeController.text}'/${coinTypeController.text}'/${accountController.text}'/${chainController.text}/${indexController.text}";

    final keyData = await SparkAddressGenerator.generateKeyData(
        mnemonicController.text, derivePath);
    setState(() {
      keyDataController.text = keyData;
    });
  }

  Future<void> getAddress() async {
    final address = await SparkAddressGenerator.getAddress(
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

    final keyData = await SparkAddressGenerator.generateKeyData(
        mnemonicController.text, derivePath);

    setState(() {
      keyDataController.text = keyData;
    });

    await getAddress();
  }

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance
        .addPostFrameCallback((_) => generateKeyDataAndGetAddress());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spark Mobile Addresses'),
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

                    generateKeyDataAndGetAddress();
                  }),
                  child: const Text('Generate Mnemonic'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: mnemonicController,
              decoration:
                  const InputDecoration(labelText: 'Mnemonic Recovery Phrase'),
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
    );
  }
}
