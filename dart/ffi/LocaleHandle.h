
#pragma once

#include "Export.h"
#include "OpaqueHandle.h"
#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

_GLUECODIUM_FFI_EXPORT FfiOpaqueHandle library_locale_create_handle(
    const char* language_code,
    const char* country_code,
    const char* script_code,
    const char* language_tag);
_GLUECODIUM_FFI_EXPORT void library_locale_release_handle(FfiOpaqueHandle handle);
_GLUECODIUM_FFI_EXPORT const char* library_locale_get_language_code(FfiOpaqueHandle handle);
_GLUECODIUM_FFI_EXPORT const char* library_locale_get_country_code(FfiOpaqueHandle handle);
_GLUECODIUM_FFI_EXPORT const char* library_locale_get_script_code(FfiOpaqueHandle handle);
_GLUECODIUM_FFI_EXPORT const char* library_locale_get_language_tag(FfiOpaqueHandle handle);

#ifdef __cplusplus
}
#endif
