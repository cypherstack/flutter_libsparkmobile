import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter/material.dart';
import 'package:flutter_libsparkmobile_example/views/address_view.dart';
import 'package:flutter_libsparkmobile_example/views/id_coin_view.dart';

void main() async {
  await coinlib.loadCoinlib();

  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spark Mobile Example App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(
                    builder: (_) => const AddressView(),
                  ),
                );
              },
              child: const Text(
                "Addresses",
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(
                    builder: (_) => const IdCoinView(),
                  ),
                );
              },
              child: const Text(
                "ID Coin",
              ),
            )
          ],
        ),
      ),
    );
  }
}
