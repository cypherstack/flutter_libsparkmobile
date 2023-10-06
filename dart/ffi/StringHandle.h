
#pragma once

#include "Export.h"
#include "OpaqueHandle.h"

#ifdef __cplusplus
extern "C" {
#endif

_GLUECODIUM_FFI_EXPORT FfiOpaqueHandle library_std_string_create_handle(const char* c_str);
_GLUECODIUM_FFI_EXPORT void library_std_string_release_handle(FfiOpaqueHandle handle);
_GLUECODIUM_FFI_EXPORT const char* library_std_string_get_value(FfiOpaqueHandle handle);

#ifdef __cplusplus
}
#endif
