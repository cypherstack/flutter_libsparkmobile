/*

 *
 */

#pragma once

#include "JniReference.h"

#include <memory>
#include <mutex>
#include <unordered_map>

namespace jni
{

class JNIEXPORT JniWrapperCache
{
public:
    template<class T>
    static void cache_wrapper(JNIEnv* jenv, std::shared_ptr<T> nobj, const JniReference<jobject>& jobj) {
        std::lock_guard<std::mutex> lock(s_mutex);
        s_wrapper_cache[nobj.get()] = jenv->NewWeakGlobalRef(jobj.get());
    }

    template<class T>
    static JniReference<jobject> get_cached_wrapper(JNIEnv* jenv, std::shared_ptr<T> nobj) {
        std::lock_guard<std::mutex> lock(s_mutex);

        auto iter = s_wrapper_cache.find(nobj.get());
        if (iter == s_wrapper_cache.end()) return {};

        auto jobj = jenv->NewLocalRef(iter->second);
        if (jenv->IsSameObject(jobj, NULL)) {
            jenv->DeleteLocalRef(jobj);
            return {};
        } else {
            return make_local_ref(jenv, jobj);
        }
    }

    template<class T>
    static void remove_cached_wrapper(JNIEnv* jenv, std::shared_ptr<T> nobj) {
        std::lock_guard<std::mutex> lock(s_mutex);

        auto iter = s_wrapper_cache.find(nobj.get());
        if (iter == s_wrapper_cache.end()) return;

        jenv->DeleteWeakGlobalRef(iter->second);
        s_wrapper_cache.erase(iter);
    }

private:
    static std::mutex s_mutex;
    static std::unordered_map<const void*, jobject> s_wrapper_cache;
};

}
