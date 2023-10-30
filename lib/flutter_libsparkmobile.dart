
import 'flutter_libsparkmobile_platform_interface.dart';

class FlutterLibsparkmobile {
  Future<String?> getPlatformVersion() {
    return FlutterLibsparkmobilePlatform.instance.getPlatformVersion();
  }
}
