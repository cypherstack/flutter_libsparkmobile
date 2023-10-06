
#pragma once

#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

namespace ffi
{
struct ProxyCacheKey
{
    uint64_t token;
    int32_t isolate_id;
    std::string type_key;

    bool
    operator==(const ProxyCacheKey& other) const {
        return token == other.token && isolate_id == other.isolate_id && type_key == other.type_key;
    }
};

struct ProxyCacheKeyHash
{
    inline size_t
    operator()(const ProxyCacheKey& key) const {
        size_t result = 7;
        result = 31 * result + key.token;
        result = 31 * result + key.isolate_id;
        result = 31 * result + std::hash<::std::string>{}(key.type_key);
        return result;
    }
};

extern std::unordered_map<ProxyCacheKey, std::weak_ptr<void>, ProxyCacheKeyHash> _proxy_cache;
extern std::mutex _cache_mutex;

template<class T>
std::shared_ptr<T>
get_cached_proxy(uint64_t token, int32_t isolate_id, const std::string& type_key) {
    const std::lock_guard<std::mutex> lock(_cache_mutex);
    auto iter = _proxy_cache.find({token, isolate_id, type_key});
    return (iter != _proxy_cache.end())
        ? std::static_pointer_cast<T>(iter->second.lock())
        : std::shared_ptr<T>{};
}

template<class T>
void
cache_proxy(uint64_t token, int32_t isolate_id, const std::string& type_key, std::shared_ptr<T> proxy) {
    const std::lock_guard<std::mutex> lock(_cache_mutex);
    _proxy_cache[{token, isolate_id, type_key}] =
        std::weak_ptr<void>(std::static_pointer_cast<void>(proxy));
}

void remove_cached_proxy(uint64_t token, int32_t isolate_id, const std::string& type_key);

}
