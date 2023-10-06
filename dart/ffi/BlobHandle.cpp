
#include "BlobHandle.h"
#include <memory>
#include <new>
#include <vector>

namespace {
using BlobPtr = std::shared_ptr<std::vector<uint8_t>>;
}

#ifdef __cplusplus
extern "C" {
#endif

FfiOpaqueHandle
library_blob_create_handle(uint64_t length) {
    return reinterpret_cast<FfiOpaqueHandle>(new (std::nothrow) BlobPtr(new std::vector<uint8_t>(length)));
}

void
library_blob_release_handle(FfiOpaqueHandle handle) {
    delete reinterpret_cast<BlobPtr*>(handle);
}

uint64_t
library_blob_get_length(FfiOpaqueHandle handle) {
    return (*reinterpret_cast<BlobPtr*>(handle))->size();
}

uint8_t*
library_blob_get_data_pointer(FfiOpaqueHandle handle) {
    return (*reinterpret_cast<BlobPtr*>(handle))->data();
}

#ifdef __cplusplus
}
#endif
