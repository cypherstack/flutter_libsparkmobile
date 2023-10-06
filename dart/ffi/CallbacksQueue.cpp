
#include "CallbacksQueue.h"

namespace ffi
{
CallbackQueueManager cbqm;

std::future<bool>
CallbackQueue::enqueueIncoming(std::function<void()> func)
{
    std::unique_lock<std::mutex> lock(m_mutex);

    if (m_is_closed) {
        std::promise<bool> done;
        done.set_value(false);
        return done.get_future();
    }

    if (!m_has_incoming) {
        m_has_incoming = true;
        m_notified.notify_one();
    }

    m_queue.emplace(Entry{std::move(func), std::promise<bool>()});

    return m_queue.back().done.get_future();
}

CallbackQueue::WaitResult
CallbackQueue::waitForIncoming(const std::chrono::milliseconds& timeout)
{
    std::unique_lock<std::mutex> lock(m_mutex);

    auto check_condition = [this] { return m_has_incoming || m_is_closed; };

    if (timeout == std::chrono::milliseconds::zero()) {
        m_notified.wait(lock, check_condition);
    } else if (!m_notified.wait_for(lock, timeout, check_condition)) {
        return WaitResult::TimedOut;
    }

    if (m_is_closed) {
        return WaitResult::Stopped;
    }

    m_has_incoming = false;
    return WaitResult::HasIncoming;
}

void
CallbackQueue::executeScheduled()
{
    std::unique_lock<std::mutex> lock(m_mutex);

    while (!m_is_closed && !m_queue.empty()) {
        auto entry = std::move(m_queue.front());
        m_queue.pop();

        m_mutex.unlock();
        entry.func();
        m_mutex.lock();

        entry.done.set_value(true);
    }
}

void
CallbackQueue::close()
{
    std::unique_lock<std::mutex> lock(m_mutex);

    if (m_is_closed) {
        return;
    }

    m_is_closed = true;
    m_notified.notify_one();

    while (!m_queue.empty()) {
        auto entry = std::move(m_queue.front());
        m_queue.pop();
        entry.done.set_value(false);
    }
}

int32_t
CallbackQueueManager::createQueue()
{
    std::unique_lock<std::mutex> lock(m_mutex);

    auto id = m_next_id++;
    m_queues.emplace(id, std::make_shared<CallbackQueue>());
    return id;
}

void
CallbackQueueManager::closeQueue(int id)
{
    std::unique_lock<std::mutex> lock(m_mutex);

    auto it = m_queues.find(id);
    if (it != m_queues.end())
    {
        it->second.get()->close();
        m_queues.erase(id);
    }
}

void
CallbackQueueManager::closeAllQueues()
{
    std::unique_lock<std::mutex> lock(m_mutex);

    for (const auto& queue : m_queues)
    {
        queue.second.get()->close();
    }
    m_queues.clear();
}

std::shared_ptr<CallbackQueue>
CallbackQueueManager::getQueue(int id) const
{
    std::unique_lock<std::mutex> lock(m_mutex);

    auto it = m_queues.find(id);
    return it == m_queues.end() ? std::shared_ptr<CallbackQueue>() : it->second;
}

std::future<bool>
CallbackQueueManager::enqueueCallback(int id, std::function<void()>&& func)
{
    auto queue = getQueue(id);
    if (!queue) {
        std::promise<bool> done;
        done.set_value(false);
        return done.get_future();
    }

    return queue->enqueueIncoming(std::move(func));
}
}
