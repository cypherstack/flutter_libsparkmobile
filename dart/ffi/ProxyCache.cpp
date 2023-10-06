
#include "ProxyCache.h"

namespace ffi
{

std::unordered_map<ProxyCacheKey, std::weak_ptr<void>, ProxyCacheKeyHash> _proxy_cache{};
std::mutex _cache_mutex{};

void
remove_cached_proxy(uint64_t token, int32_t isolate_id, const std::string& type_key) {
    const std::lock_guard<std::mutex> lock(_cache_mutex);
    _proxy_cache.erase({token, isolate_id, type_key});
}

}
