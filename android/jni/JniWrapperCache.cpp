/*

 *
 */

#include "JniWrapperCache.h"

namespace jni
{
std::mutex JniWrapperCache::s_mutex{};
std::unordered_map<const void*, jobject> JniWrapperCache::s_wrapper_cache{};
}
