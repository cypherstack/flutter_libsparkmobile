
#include "StringHandle.h"
#include <new>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

FfiOpaqueHandle
library_std_string_create_handle(const char* c_str)
{
    return reinterpret_cast<FfiOpaqueHandle>(new (std::nothrow) std::string(c_str));
}

void
library_std_string_release_handle(FfiOpaqueHandle handle)
{
    delete reinterpret_cast<std::string*>(handle);
}

const char*
library_std_string_get_value(FfiOpaqueHandle handle)
{
    return reinterpret_cast<std::string*>(handle)->c_str();
}

#ifdef __cplusplus
}
#endif
