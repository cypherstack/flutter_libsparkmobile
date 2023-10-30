#include "include/flutter_libsparkmobile/flutter_libsparkmobile_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_libsparkmobile_plugin.h"

void FlutterLibsparkmobilePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_libsparkmobile::FlutterLibsparkmobilePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
