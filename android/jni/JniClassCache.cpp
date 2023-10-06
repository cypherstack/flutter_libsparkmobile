/*

 *
 */

#include "JniClassCache.h"

#include <functional>
#include <list>
#include <unordered_map>

namespace jni
{

namespace
{
std::list<::jni::CachedJavaClassBase*>& get_registered_class_cache_list()
{
    static std::list<::jni::CachedJavaClassBase*> list;
    return list;
}

std::unordered_map<TypeId, jni::JniReference<jclass>*>& get_instance_class_map()
{
    static std::unordered_map<TypeId, jni::JniReference<jclass>*> classes;
    return classes;
}

}

void
CachedJavaClassBase::init(JNIEnv* env)
{
    for (auto registered_class_base : get_registered_class_cache_list())
    {
        registered_class_base->do_init(env);
    }
    get_registered_class_cache_list().clear();
}

CachedJavaClassBase::CachedJavaClassBase(const char* name)
    : CachedJavaClassBase(name, nullptr)
{
}

CachedJavaClassBase::CachedJavaClassBase(const char* name, const char* cpp_name)
    : m_name(name)
    , m_cpp_name(cpp_name)
{
    get_registered_class_cache_list().push_back(this);
}

jni::JniReference<jclass>*
CachedJavaClassBase::get_java_class_for_instance(const TypeId& id) {
    const auto& classes = get_instance_class_map();
    const auto& found = classes.find(id);
    return found != classes.end() ? found->second : nullptr;
}

CachedJavaClassBase::~CachedJavaClassBase() = default;

void
CachedJavaClassBase::do_init(JNIEnv* env)
{
    auto global_ref = new_global_ref(env, find_class(env, m_name).get());
    auto java_class = set_java_class(make_non_releasing_ref(global_ref.release()));
    if (m_cpp_name) {
        get_instance_class_map().insert(std::make_pair(m_cpp_name, java_class));
    }
}

namespace
{
struct DummyNativeBaseType {};
struct DummyDurationType {};
}

REGISTER_JNI_CLASS_CACHE("com/example/NativeBase", com_example_DummyNativeBaseType, DummyNativeBaseType)
REGISTER_JNI_CLASS_CACHE("com/example/time/Duration", com_example_time_DummyDurationType, DummyDurationType)

JniReference<jclass>& get_cached_native_base_class()
{
    return CachedJavaClass<DummyNativeBaseType>::java_class;
}

JniReference<jclass>& get_cached_duration_class()
{
    return CachedJavaClass<DummyDurationType>::java_class;
}

}
