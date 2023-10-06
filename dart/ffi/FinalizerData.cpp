
#include "FinalizerData.h"

#ifdef __cplusplus
extern "C" {
#endif

void
library_execute_finalizer(void*, void* data) {
    FinalizerData* finalizer_data = reinterpret_cast<FinalizerData*>(data);
    if (finalizer_data->ffi_handle == nullptr || finalizer_data->finalizer == nullptr) return;

    finalizer_data->finalizer(finalizer_data->ffi_handle, finalizer_data->isolate_id);

    finalizer_data->ffi_handle = nullptr;
    finalizer_data->finalizer = nullptr;

    delete finalizer_data;
}

#ifdef __cplusplus
}
#endif

