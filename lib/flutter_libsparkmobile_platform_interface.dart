import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_libsparkmobile_method_channel.dart';

abstract class FlutterLibsparkmobilePlatform extends PlatformInterface {
  /// Constructs a FlutterLibsparkmobilePlatform.
  FlutterLibsparkmobilePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterLibsparkmobilePlatform _instance = MethodChannelFlutterLibsparkmobile();

  /// The default instance of [FlutterLibsparkmobilePlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterLibsparkmobile].
  static FlutterLibsparkmobilePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterLibsparkmobilePlatform] when
  /// they register themselves.
  static set instance(FlutterLibsparkmobilePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
