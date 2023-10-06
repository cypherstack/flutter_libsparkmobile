
#include "CallbacksHandle.h"

#include "CallbacksQueue.h"

namespace {
// Due to the bug in Flutter (https://github.com/flutter/flutter/issues/58987)
// hot restart may hangs if isolate is waiting for event in C++.
// This workaround makes waiting for callback non blocking
// so execution periodically returns to Flutter and the issue is eliminated.
const std::chrono::milliseconds g_wait_timeout = std::chrono::seconds(1);
}

#ifdef __cplusplus
extern "C" {
#endif

int32_t
library_library_callbacks_queue_init(bool is_main_isolate) {
    if (is_main_isolate) {
        // This is required to clean up after hot restart.
        ffi::cbqm.closeAllQueues();
    }
    return ffi::cbqm.createQueue();
}

void
library_library_callbacks_queue_release(int32_t isolate_id) {
    ffi::cbqm.closeQueue(isolate_id);
}

uint8_t
library_library_wait_for_callbacks(int32_t isolate_id) {
    if (auto queue = ffi::cbqm.getQueue(isolate_id)) {
      return static_cast<uint8_t>(queue->waitForIncoming(g_wait_timeout));
    }
    return static_cast<uint8_t>(ffi::CallbackQueue::WaitResult::Stopped);
}

void
library_library_execute_callbacks(int32_t isolate_id) {
    auto queue = ffi::cbqm.getQueue(isolate_id);
    if (queue) {
        queue->executeScheduled();
    }
}

#ifdef __cplusplus
}
#endif
