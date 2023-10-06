/*

 *
 */

#pragma once

#include <jni.h>

#include "JniCallJavaMethod.h"
#include "JniClassCache.h"
#include "JniReference.h"
#include "Locale.h"

#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace jni
{

// ------------------- JNI to C++ conversion functions ---------------------------------------------

/**
 * Converts a JNI jstring to an std::string.
 */
JNIEXPORT std::string convert_from_jni( JNIEnv* env, const JniReference<jobject>& jvalue, std::string* );
JNIEXPORT std::string convert_from_jni( JNIEnv* env, const JniReference<jstring>& jvalue, std::string* );
JNIEXPORT std::optional<std::string> convert_from_jni(
    JNIEnv* env, const JniReference<jobject>& jvalue, std::optional<std::string>* );
JNIEXPORT std::optional<std::string> convert_from_jni(
    JNIEnv* env, const JniReference<jstring>& jvalue, std::optional<std::string>* );

/**
 * Converts a jbyteArray to a byte buffer
 */
JNIEXPORT std::shared_ptr< ::std::vector< uint8_t > > convert_from_jni(
    JNIEnv* env, const JniReference<jbyteArray>& jvalue, std::shared_ptr< ::std::vector< uint8_t > >* );
JNIEXPORT std::optional<std::shared_ptr< ::std::vector< uint8_t > > > convert_from_jni(
    JNIEnv* env, const JniReference<jbyteArray>& jvalue,
    std::optional< std::shared_ptr< ::std::vector< uint8_t > > >* );

/**
 * Converts a Java Date object to an std::chrono::time_point.
 */
template<class Clock, class Duration>
std::chrono::time_point<Clock, Duration>
convert_from_jni(JNIEnv* env, const JniReference<jobject>& jvalue, std::chrono::time_point<Clock, Duration>*) {
    if (!jvalue)
    {
        auto exceptionClass = ::jni::find_class(env, "java/lang/NullPointerException");
        env->ThrowNew(exceptionClass.get(), "");
        return {};
    }

    auto javaDateClass = find_class(env, "java/util/Date");
    auto getTimeMethodId = env->GetMethodID(javaDateClass.get(), "getTime", "()J");
    jlong time_ms_epoch = call_java_method<jlong>(env, jvalue, getTimeMethodId);

    using namespace std::chrono;
    return time_point<Clock, Duration>(duration_cast<Duration>(milliseconds(time_ms_epoch)));
}

template<class Clock, class Duration>
std::optional<std::chrono::time_point<Clock, Duration>>
convert_from_jni(
    JNIEnv* env,
    const JniReference<jobject>& jvalue,
    std::optional<std::chrono::time_point<Clock, Duration>>*
) {
    return jvalue
        ? std::optional<std::chrono::time_point<Clock, Duration>>(
            convert_from_jni(env, jvalue, (std::chrono::time_point<Clock, Duration>*)nullptr)
        )
        : std::optional<std::chrono::time_point<Clock, Duration>>{};
}

/**
 * Converts a Java Duration object to an std::chrono::duration<>.
 */
template<class Rep, class Period>
std::chrono::duration<Rep, Period>
convert_from_jni(JNIEnv* env, const JniReference<jobject>& jvalue, std::chrono::duration<Rep, Period>*) {
    if (!jvalue) {
        auto exceptionClass = ::jni::find_class(env, "java/lang/NullPointerException");
        env->ThrowNew(exceptionClass.get(), "");
        return {};
    }

    auto& javaDurationClass = get_cached_duration_class();
    auto getSecondsMethodId = env->GetMethodID(javaDurationClass.get(), "getSeconds", "()J");
    jlong seconds_value = call_java_method<jlong>(env, jvalue, getSecondsMethodId);
    auto getNanoMethodId = env->GetMethodID(javaDurationClass.get(), "getNano", "()I");
    jint nano_value = call_java_method<jint>(env, jvalue, getNanoMethodId);

    using namespace std::chrono;

    auto seconds_division = std::lldiv(seconds_value * Period::den, Period::num);
    auto combined_nano_value =
        duration_cast<nanoseconds>(seconds(seconds_division.rem)).count() + nano_value;
    auto num = Period::den * nanoseconds::period::num;
    auto den = Period::num * nanoseconds::period::den;
    auto nano_division = std::lldiv(combined_nano_value * num, den);
    auto result_value = seconds_division.quot + nano_division.quot;

    // Rounding
    if (2 * nano_division.rem >= den) {
        result_value += 1;
    }

    return duration<Rep, Period>(result_value);
}

template<class Rep, class Period>
std::optional<std::chrono::duration<Rep, Period>>
convert_from_jni(
    JNIEnv* env, const JniReference<jobject>& jvalue,
    std::optional<std::chrono::duration<Rep, Period>>*
) {

    return jvalue
        ? std::optional<std::chrono::duration<Rep, Period>>(
            convert_from_jni( env, jvalue, (std::chrono::duration<Rep, Period>*)nullptr))
        : std::optional<std::chrono::duration<Rep, Period>>{};
}

/**
 * Converts a Java Locale object to ::Locale.
 */
JNIEXPORT ::Locale convert_from_jni(
    JNIEnv* env, const JniReference<jobject>& jvalue, ::Locale*);
JNIEXPORT std::optional<::Locale> convert_from_jni(
    JNIEnv* env, const JniReference<jobject>& jvalue,
    std::optional<::Locale>*);

// -------------------- C++ to JNI conversion functions --------------------------------------------

/**
 * Converts an std::string to a JNI jstring
 */
JNIEXPORT JniReference<jstring> convert_to_jni( JNIEnv* env, const std::string& nvalue );
JNIEXPORT JniReference<jstring> convert_to_jni( JNIEnv* env, const std::optional<std::string>& nvalue );

/**
 * Converts a byte buffer to a jbyteArray
 */
JNIEXPORT JniReference<jbyteArray> convert_to_jni( JNIEnv* env, const std::shared_ptr< ::std::vector< uint8_t > >& nvalue );
JNIEXPORT JniReference<jbyteArray> convert_to_jni(
    JNIEnv* env, const std::optional< std::shared_ptr< ::std::vector< uint8_t > > >& nvalue );

/**
 * Converts an std::chrono::time_point to a Java Date object.
 */
template<class Clock, class Duration>
JniReference<jobject>
convert_to_jni(JNIEnv* env, const std::chrono::time_point<Clock, Duration>& nvalue) {
    auto javaDateClass = find_class(env, "java/util/Date");
    jlong time_ms_epoch = std::chrono::duration_cast<std::chrono::milliseconds>(nvalue.time_since_epoch()).count();

    auto constructorMethodId = env->GetMethodID(javaDateClass.get(), "<init>", "(J)V");
    return new_object(env, javaDateClass, constructorMethodId, time_ms_epoch);
}

template<class Clock, class Duration>
JniReference<jobject>
convert_to_jni(JNIEnv* env, const std::optional<std::chrono::time_point<Clock, Duration>>& nvalue) {
    return nvalue ? convert_to_jni(env, *nvalue) : JniReference<jobject>{};
}

/**
 * Converts an std::chrono::duration<> to a Java Duration object.
 */
template<class Rep, class Period>
JniReference<jobject>
convert_to_jni(JNIEnv* env, const std::chrono::duration<Rep, Period>& nvalue) {
    auto& javaDurationClass = get_cached_duration_class();
    auto factoryMethodId = env->GetStaticMethodID(javaDurationClass.get(), "ofSeconds", "(JJ)Lcom/example/time/Duration;");

    using namespace std::chrono;
    auto seconds_duration = duration_cast<seconds>(nvalue);
    auto seconds_value = duration_cast<seconds>(nvalue).count();
    auto nanos_adjustment = duration_cast<nanoseconds>(nvalue - seconds_duration).count();
    return make_local_ref(env, env->CallStaticObjectMethod(javaDurationClass.get(), factoryMethodId, seconds_value, nanos_adjustment));
}

/**
 * Converts ::Locale to a Java Locale object.
 */
JNIEXPORT JniReference<jobject> convert_to_jni(JNIEnv* env, const ::Locale& nvalue);
JNIEXPORT JniReference<jobject> convert_to_jni(
    JNIEnv* env, const std::optional<::Locale>& nvalue);

template<class Rep, class Period>
JNIEXPORT JniReference<jobject> convert_to_jni(
    JNIEnv* env, const std::optional<std::chrono::duration<Rep, Period>>& nvalue ) {

    return nvalue ? convert_to_jni(env, *nvalue) : JniReference<jobject>{};
}


// -------------------- std::optional<std::function<>> conversion functions -----------------------------

template<class R, class... Args>
std::optional<std::function<R(Args...)>>
convert_from_jni(JNIEnv* _jenv, const JniReference<jobject>& _jinput, std::optional<std::function<R(Args...)>>*)
{
    return _jinput
        ? convert_from_jni(_jenv, _jinput, (std::function<R(Args...)>*)nullptr)
        : std::optional<std::function<R(Args...)>>{};
}

template<class R, class... Args>
JniReference<jobject>
convert_to_jni(JNIEnv* _jenv, const std::optional<std::function<R(Args...)>> _ninput)
{
    return _ninput ? convert_to_jni(_jenv, *_ninput) : JniReference<jobject>{};
}

// -------------------- createCppProxy() default implementation ------------------------------------

template<class T>
void createCppProxy(JNIEnv* /*env*/, const JniReference<jobject>& /*obj*/, ::std::shared_ptr<T>& /*result*/) {}

}
