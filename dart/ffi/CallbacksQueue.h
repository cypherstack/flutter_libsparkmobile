
#pragma once

#include <chrono>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <queue>
#include <unordered_map>

namespace ffi
{
/**
 * A queue that manages a list of callbacks.
 */
class CallbackQueue
{
private:
    struct Entry
    {
        const std::function<void()> func;
        std::promise<bool> done;
    };

    mutable std::mutex m_mutex;
    std::queue<Entry> m_queue;

    bool m_is_closed = false;
    bool m_has_incoming = false;

    std::condition_variable m_notified;

public:
    enum class WaitResult {
        Stopped,      // Queue is stopped
        HasIncoming,  // Queue has incomming messages
        TimedOut      // Wait operation is timed out
    };

    /**
     * Block until there is a callback in incoming or the queue is closed
     * or given timeout is over.
     * The incoming callbacks are moved to scheduled.
     *
     * Returns result of operation as value of WaitResult enumeration.  
     */

    WaitResult waitForIncoming(const std::chrono::milliseconds& timeout);

    /**
     * Execute scheduled callbacks on current thread.
     */
    void executeScheduled();

    /**
     * Add a callback to incoming.
     */
    std::future<bool> enqueueIncoming(std::function<void()> func);

    /**
     * Close the queue.
     */
    void close();
};

/**
 * Manages a set of CallbackQueues identified by int ids.
 */
class CallbackQueueManager
{
private:
    mutable std::mutex m_mutex;
    int32_t m_next_id = 0;
    std::unordered_map<int, std::shared_ptr<CallbackQueue>> m_queues;

public:
    std::shared_ptr<CallbackQueue> getQueue(int id) const;

    /**
     * Create CallbackQeue with given id.
     **/
    int createQueue();

    /**
     * Close CallbackQueue of given id.
     **/
    void closeQueue(int id);

    /**
     * Close all CallbackQueues.
     **/
    void closeAllQueues();

    /**
     * Enqueues a callback into the given queue.
     * Ignores the callback if the queue not exist or was already closed.
     **/
    std::future<bool> enqueueCallback(int id, std::function<void()>&& func);
};

/**
 * Global static instance of CallbackQueueManager.
 **/
extern CallbackQueueManager cbqm;
}
