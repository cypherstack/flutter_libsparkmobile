
#pragma once

#include "Export.h"
#include "OpaqueHandle.h"
#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

_GLUECODIUM_FFI_EXPORT FfiOpaqueHandle library_blob_create_handle(uint64_t length);
_GLUECODIUM_FFI_EXPORT void library_blob_release_handle(FfiOpaqueHandle handle);
_GLUECODIUM_FFI_EXPORT uint64_t library_blob_get_length(FfiOpaqueHandle iterator_handle);
_GLUECODIUM_FFI_EXPORT uint8_t* library_blob_get_data_pointer(FfiOpaqueHandle iterator_handle);

#ifdef __cplusplus
}
#endif
