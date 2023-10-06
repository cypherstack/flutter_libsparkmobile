
#pragma once

#include "Export.h"
#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

_GLUECODIUM_FFI_EXPORT int32_t library_library_callbacks_queue_init(bool is_main_isolate);
_GLUECODIUM_FFI_EXPORT void library_library_callbacks_queue_release(int32_t isolate_id);
_GLUECODIUM_FFI_EXPORT uint8_t library_library_wait_for_callbacks(int32_t isolate_id);
_GLUECODIUM_FFI_EXPORT void library_library_execute_callbacks(int32_t isolate_id);

#ifdef __cplusplus
}
#endif
