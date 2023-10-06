
#include "IsolateContext.h"

namespace ffi
{

namespace
{
thread_local int32_t s_current_id = -1;
}

IsolateContext::IsolateContext(int32_t isolate_id) : m_previous_id(s_current_id) {
    s_current_id = isolate_id;
}

IsolateContext::~IsolateContext() {
    s_current_id = m_previous_id;
}

bool
IsolateContext::is_current(int32_t isolate_id) {
    return s_current_id == isolate_id;
}

}
