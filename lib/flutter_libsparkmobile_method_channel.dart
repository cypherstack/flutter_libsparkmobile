import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_libsparkmobile_platform_interface.dart';

/// An implementation of [FlutterLibsparkmobilePlatform] that uses method channels.
class MethodChannelFlutterLibsparkmobile extends FlutterLibsparkmobilePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_libsparkmobile');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
