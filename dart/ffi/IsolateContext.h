
#pragma once

#include "Export.h"
#include <cstdint>

namespace ffi
{
class _GLUECODIUM_FFI_EXPORT IsolateContext
{
public:
    explicit IsolateContext(int32_t isolate_id);
    ~IsolateContext();
    static bool is_current(int32_t isolate_id);

private:
    const int32_t m_previous_id;
};
}
