import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter/material.dart';
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_libsparkmobile_example/views/address_view.dart';
import 'package:flutter_libsparkmobile_example/views/id_coin_view.dart';
import 'package:logger/logger.dart';

extension _LL on LoggingLevel {
  Level getLoggerLevel() {
    switch (this) {
      case LoggingLevel.info:
        return Level.info;
      case LoggingLevel.warning:
        return Level.warning;
      case LoggingLevel.error:
        return Level.error;
      case LoggingLevel.fatal:
        return Level.fatal;
      case LoggingLevel.debug:
        return Level.debug;
      case LoggingLevel.trace:
        return Level.trace;
    }
  }
}

void main() async {
  await coinlib.loadCoinlib();

  final logger = Logger(
    printer: PrefixPrinter(
      PrettyPrinter(
        printEmojis: false,
        methodCount: 0,
        dateTimeFormat: DateTimeFormat.dateAndTime,
        colors: true,
      ),
    ),
  );

  Log.levels.addAll(LoggingLevel.values);
  Log.onLog = (
    LoggingLevel level,
    Object? value, {
    Error? error,
    StackTrace? stackTrace,
    required DateTime time,
  }) {
    logger.log(
      level.getLoggerLevel(),
      value,
      error: error,
      stackTrace: stackTrace,
      time: time,
    );
  };

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
