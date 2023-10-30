#ifndef FLUTTER_PLUGIN_FLUTTER_LIBSPARKMOBILE_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_LIBSPARKMOBILE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_libsparkmobile {

class FlutterLibsparkmobilePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterLibsparkmobilePlugin();

  virtual ~FlutterLibsparkmobilePlugin();

  // Disallow copy and assign.
  FlutterLibsparkmobilePlugin(const FlutterLibsparkmobilePlugin&) = delete;
  FlutterLibsparkmobilePlugin& operator=(const FlutterLibsparkmobilePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_libsparkmobile

#endif  // FLUTTER_PLUGIN_FLUTTER_LIBSPARKMOBILE_PLUGIN_H_
