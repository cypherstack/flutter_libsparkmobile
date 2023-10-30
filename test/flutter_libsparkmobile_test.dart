import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_libsparkmobile/flutter_libsparkmobile_platform_interface.dart';
import 'package:flutter_libsparkmobile/flutter_libsparkmobile_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterLibsparkmobilePlatform
    with MockPlatformInterfaceMixin
    implements FlutterLibsparkmobilePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterLibsparkmobilePlatform initialPlatform = FlutterLibsparkmobilePlatform.instance;

  test('$MethodChannelFlutterLibsparkmobile is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterLibsparkmobile>());
  });

  test('getPlatformVersion', () async {
    FlutterLibsparkmobile flutterLibsparkmobilePlugin = FlutterLibsparkmobile();
    MockFlutterLibsparkmobilePlatform fakePlatform = MockFlutterLibsparkmobilePlatform();
    FlutterLibsparkmobilePlatform.instance = fakePlatform;

    expect(await flutterLibsparkmobilePlugin.getPlatformVersion(), '42');
  });
}
