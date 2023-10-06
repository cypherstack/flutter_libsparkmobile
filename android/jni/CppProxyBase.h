/*

 *
 */

#pragma once

#include <jni.h>

#include "JniTemplateMetainfo.h"
#include "JniReference.h"
#include "JniCallJavaMethod.h"
#include "JniCallbackErrorChecking.h"

#include <memory>
#include <mutex>
#include <new>
#include <string>
#include <unordered_map>

namespace jni
{

class JNIEXPORT CppProxyBase
{
private:
    template < typename ResultType, typename ImplType >
    static void
    createProxy( JNIEnv* jenv,
                 const JniReference<jobject>& jobj,
                 const ::std::string& type_key,
                 bool do_cache,
                 ::std::shared_ptr< ResultType >& result )
    {
        JniReference<jobject> globalRef = new_global_ref( jenv, jobj.get() );
        jint jHashCode = getHashCode( jenv, jobj.get() );
        ProxyCacheKey key{globalRef.get(), jHashCode, type_key};

        ::std::lock_guard< GlobalJniLock > lock( sGlobalJniLock );
        sGlobalJniLock.setJniEnvForCurrentThread( jenv );

        if (do_cache) {
            auto iterator = sProxyCache.find( key );
            if ( iterator != sProxyCache.end( ) )
            {
                auto cachedProxy = iterator->second.lock( );
                if ( cachedProxy )
                {
                    result = ::std::static_pointer_cast< ImplType >( cachedProxy );
                    return;
                }
            }
        }

        auto newProxyInstance = new (::std::nothrow ) ImplType( jenv, std::move(globalRef), jHashCode );
        if ( newProxyInstance == nullptr )
        {
            throw_runtime_exception( jenv, "Cannot allocate native memory." );
            return;
        }
        auto newProxy = ::std::shared_ptr< ImplType >( newProxyInstance );
        result = newProxy;

        if (do_cache) {
            sProxyCache[ key ] = ::std::weak_ptr< ImplType >( newProxy );
            registerInReverseCache(newProxyInstance, result.get(), key.jObject);
        }
    }

public:
    template < typename ResultType, typename ImplType >
    static void
    createProxy( JNIEnv* jenv,
                 const JniReference<jobject>& jobj,
                 const ::std::string& type_key,
                 ::std::shared_ptr< ResultType >& result )
    {
        createProxy<ResultType, ImplType>(jenv, jobj, type_key, true, result);
    }

    template < typename ResultType, typename ImplType >
    static void
    createProxyNoCache( JNIEnv* jenv,
                 const JniReference<jobject>& jobj,
                 const ::std::string& type_key,
                 ::std::shared_ptr< ResultType >& result )
    {
        createProxy<ResultType, ImplType>(jenv, jobj, type_key, false, result);
    }

    template <class T>
    static JniReference<jobject> getJavaObject(JNIEnv* jenv, T* interfacePtr) {
        return getJavaObjectFromReverseCache(jenv, interfacePtr);
    }

protected:
    CppProxyBase( JNIEnv* jenv, JniReference<jobject> globalRef, jint jHashCode, ::std::string type_key );

    virtual ~CppProxyBase( );

    template< typename ResultType, class ... Args >
    typename std::conditional<IsDerivedFromJObject<ResultType>::value, JniReference<ResultType>, ResultType>::type
    callJavaMethod( const char* methodName,
                    const char* jniSignature,
                    JNIEnv* jniEnv,
                    const Args& ... args ) const
    {
        return call_java_method<ResultType>(jniEnv, mGlobalRef, methodName, jniSignature, args...);
    }

    static JNIEnv* getJniEnvironment( );

private:

    struct ProxyCacheKey
    {
        jobject jObject;
        jint jHashCode;
        ::std::string type_key;

        bool operator==( const ProxyCacheKey& other ) const;
    };

    struct ProxyCacheKeyHash
    {
        inline size_t
        operator( )( const ProxyCacheKey& key ) const
        {
            size_t result = 7;
            result = 31 * result + key.jHashCode;
            result = 31 * result + ::std::hash<::std::string>{}(key.type_key);
            return result;
        }
    };

    using ReverseCacheKey = const void*;

    class GlobalJniLock {
    public:
        void lock( );
        void unlock( );

        void setJniEnvForCurrentThread( JNIEnv* env );
        JNIEnv* getJniEnvForCurrentThread( );

    private:
        ::std::mutex cacheMutex;
        JNIEnv* jniEnvForCurrentThread = nullptr;
    };

    using ProxyCache
        = ::std::unordered_map< ProxyCacheKey, ::std::weak_ptr< CppProxyBase >, ProxyCacheKeyHash >;
    using ReverseProxyCache = ::std::unordered_map<ReverseCacheKey, jobject>;

private:
    static jint getHashCode( JNIEnv* jniEnv, jobject jObj );

    static void registerInReverseCache( CppProxyBase* proxyBase,
                                        ReverseCacheKey reverseCacheKey,
                                        const jobject& jObj );
    void removeSelfFromReverseCache( );
    static JniReference<jobject> getJavaObjectFromReverseCache(JNIEnv* jniEnv, ReverseCacheKey reverseCacheKey);

private:
    JniReference<jobject> mGlobalRef;
    jint jHashCode;
    ReverseCacheKey mReverseCacheKey = nullptr;
    const ::std::string type_key;

protected:
    static ProxyCache sProxyCache;
    static ReverseProxyCache sReverseProxyCache;
    static GlobalJniLock sGlobalJniLock;
};

}
