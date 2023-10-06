
#pragma once

#include "Export.h"
#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize Dart API with dynamic linking.
//
// Must be called with `NativeApi.initializeApiDLData` from `dart:ffi`, before using other functions.
//
// Returns 1 on success.
_GLUECODIUM_FFI_EXPORT int32_t library_dart_dl_initialize(void* initialize_api_dl_data);

#ifdef __cplusplus
}
#endif
