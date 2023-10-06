/*

 *
 */

#pragma once

#include <jni.h>

#include "JniCppConversionUtils.h"
#include "JniReference.h"
#include "Locale.h"

#include <chrono>
#include <cstdint>
#include <memory>
#include <optional>
#include <vector>

namespace jni
{

// -------------------- JNI object field getters --------------------------------------------------

JNIEXPORT JniReference< jobject > get_object_field_value( JNIEnv* env,
                                       const JniReference<jobject>& object,
                                       const char* fieldName,
                                       const char* fieldSignature );

JNIEXPORT bool get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, bool* );
JNIEXPORT int8_t get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, int8_t* );
JNIEXPORT int16_t get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, int16_t* );
JNIEXPORT int32_t get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, int32_t* );
JNIEXPORT int64_t get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, int64_t* );
JNIEXPORT uint8_t get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, uint8_t* );
JNIEXPORT uint16_t get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, uint16_t* );
JNIEXPORT uint32_t get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, uint32_t* );
JNIEXPORT uint64_t get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, uint64_t* );
JNIEXPORT float get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, float* );
JNIEXPORT double get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, double* );
JNIEXPORT ::std::string get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, ::std::string* );

JNIEXPORT std::optional< bool > get_field_value( JNIEnv* env,
                                           const JniReference< jobject >& object,
                                           const char* fieldName,
                                           std::optional< bool >* );
JNIEXPORT std::optional< int8_t > get_field_value( JNIEnv* env,
                                             const JniReference< jobject >& object,
                                             const char* fieldName,
                                             std::optional< int8_t >* );
JNIEXPORT std::optional< int16_t > get_field_value( JNIEnv* env,
                                              const JniReference< jobject >& object,
                                              const char* fieldName,
                                              std::optional< int16_t >* );
JNIEXPORT std::optional< int32_t > get_field_value( JNIEnv* env,
                                              const JniReference< jobject >& object,
                                              const char* fieldName,
                                              std::optional< int32_t >* );
JNIEXPORT std::optional< int64_t > get_field_value( JNIEnv* env,
                                              const JniReference< jobject >& object,
                                              const char* fieldName,
                                              std::optional< int64_t >* );
JNIEXPORT std::optional< uint8_t > get_field_value( JNIEnv* env,
                                              const JniReference< jobject >& object,
                                              const char* fieldName,
                                              std::optional< uint8_t >* );
JNIEXPORT std::optional< uint16_t > get_field_value( JNIEnv* env,
                                               const JniReference< jobject >& object,
                                               const char* fieldName,
                                               std::optional< uint16_t >* );
JNIEXPORT std::optional< uint32_t > get_field_value( JNIEnv* env,
                                               const JniReference< jobject >& object,
                                               const char* fieldName,
                                               std::optional< uint32_t >* );
JNIEXPORT std::optional< uint64_t > get_field_value( JNIEnv* env,
                                               const JniReference< jobject >& object,
                                               const char* fieldName,
                                               std::optional< uint64_t >* );
JNIEXPORT std::optional< float > get_field_value( JNIEnv* env,
                                            const JniReference< jobject >& object,
                                            const char* fieldName,
                                            std::optional< float >* );
JNIEXPORT std::optional< double > get_field_value( JNIEnv* env,
                                             const JniReference< jobject >& object,
                                             const char* fieldName,
                                             std::optional< double >* );
JNIEXPORT std::optional< ::std::string > get_field_value( JNIEnv* env,
                                                    const JniReference< jobject >& object,
                                                    const char* fieldName,
                                                    std::optional< ::std::string >* );

JNIEXPORT ::std::shared_ptr< ::std::vector< uint8_t > > get_field_value(
    JNIEnv* env,
    const JniReference< jobject >& object,
    const char* fieldName,
    ::std::shared_ptr< ::std::vector< uint8_t > >* );
JNIEXPORT std::optional< ::std::shared_ptr< ::std::vector< uint8_t > > > get_field_value(
    JNIEnv* env,
    const JniReference< jobject >& object,
    const char* fieldName,
    std::optional< ::std::shared_ptr< ::std::vector< uint8_t > > >* );

template<class Clock, class Duration>
std::chrono::time_point<Clock, Duration>
get_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, std::chrono::time_point<Clock, Duration>*
) {
    auto fieldValue = get_object_field_value(env, object, fieldName, "Ljava/util/Date;");

    return ::jni::convert_from_jni(env, fieldValue, (std::chrono::time_point<Clock, Duration>*)nullptr);
}

template<class Clock, class Duration>
std::optional<std::chrono::time_point<Clock, Duration>>
get_field_value(
    JNIEnv* env, const JniReference<jobject >& object, const char* fieldName,
    std::optional<std::chrono::time_point<Clock, Duration>>*
) {
    auto fieldValue = get_object_field_value(env, object, fieldName, "Ljava/util/Date;");

    return ::jni::convert_from_jni(
        env, fieldValue, (std::optional<std::chrono::time_point<Clock, Duration>>*)nullptr
    );
}

JNIEXPORT ::Locale get_field_value(
    JNIEnv* env,
    const JniReference< jobject >& object,
    const char* fieldName,
    ::Locale* );
JNIEXPORT std::optional< ::Locale > get_field_value(
    JNIEnv* env,
    const JniReference< jobject >& object,
    const char* fieldName,
    std::optional< ::Locale >* );

// -------------------- JNI object field setters --------------------------------------------------

JNIEXPORT void set_object_field_value( JNIEnv* env,
                             const JniReference<jobject>& object,
                             const char* fieldName,
                             const char* fieldSignature,
                             const JniReference<jobject>& fieldValue );

JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, bool value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, int8_t value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, int16_t value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, int32_t value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, int64_t value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, uint8_t value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, uint16_t value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, uint32_t value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, uint64_t value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, float value );
JNIEXPORT void set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, double value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference<jobject>& object,
                      const char* fieldName,
                      const std::string& fieldValue );

JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< bool > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< int8_t > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< int16_t > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< int32_t > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< int64_t > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< uint8_t > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< uint16_t > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< uint32_t > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< uint64_t > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< float > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< double > value );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference< jobject >& object,
                      const char* fieldName,
                      std::optional< ::std::string > value );

JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference<jobject>& object,
                      const char* fieldName,
                      const std::shared_ptr< ::std::vector< uint8_t > >& fieldValue );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference<jobject>& object,
                      const char* fieldName,
                      std::optional< std::shared_ptr< ::std::vector< uint8_t > > > fieldValue );

template<class Clock, class Duration>
void
set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName, const std::chrono::time_point<Clock, Duration>& fieldValue
) {
    auto fieldId = env->GetFieldID(get_object_class(env, object).get(), fieldName, "Ljava/util/Date;");
    auto jValue = ::jni::convert_to_jni(env, fieldValue);
    env->SetObjectField(object.get(), fieldId, jValue.get());
}

template<class Clock, class Duration>
void
set_field_value(
    JNIEnv* env, const JniReference<jobject>& object, const char* fieldName,
    const std::optional<std::chrono::time_point<Clock, Duration>>& fieldValue
) {
    auto fieldId = env->GetFieldID(get_object_class(env, object).get(), fieldName, "Ljava/util/Date;");
    auto jValue = ::jni::convert_to_jni(env, fieldValue);
    env->SetObjectField(object.get(), fieldId, jValue.get());
}

JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference<jobject>& object,
                      const char* fieldName,
                      const ::Locale& fieldValue );
JNIEXPORT void set_field_value( JNIEnv* env,
                      const JniReference<jobject>& object,
                      const char* fieldName,
                      std::optional< ::Locale > fieldValue );

JNIEXPORT void set_object_field_value( JNIEnv* env,
                             const JniReference<jobject>& object,
                             const char* fieldName,
                             const char* fieldSignature,
                             const JniReference<jobject>& fieldValue );

// -------------------- Templated JNI field accessors for Duration types --------------------------

template<class Rep, class Period>
JNIEXPORT ::std::chrono::duration<Rep, Period> get_field_value(
    JNIEnv* env,
    const JniReference<jobject>& object,
    const char* fieldName,
    ::std::chrono::duration<Rep, Period>* ) {

    auto fieldValue = get_object_field_value(env, object, fieldName, "Lcom/example/time/Duration;");

    return ::jni::convert_from_jni(env, fieldValue, (::std::chrono::duration<Rep, Period>*)nullptr);
}

template<class Rep, class Period>
JNIEXPORT std::optional<::std::chrono::duration<Rep, Period>> get_field_value(
    JNIEnv* env,
    const JniReference<jobject>& object,
    const char* fieldName,
    std::optional<::std::chrono::duration<Rep, Period>>* ) {

    auto fieldValue = get_object_field_value(env, object, fieldName, "Lcom/example/time/Duration;");

    return ::jni::convert_from_jni(
        env, fieldValue, (std::optional<::std::chrono::duration<Rep, Period>>*)nullptr);
}

template<class Rep, class Period>
JNIEXPORT void set_field_value(
    JNIEnv* env,
    const JniReference<jobject>& object,
    const char* fieldName,
    const ::std::chrono::duration<Rep, Period>& fieldValue ) {

    auto fieldId = env->GetFieldID(get_object_class(env, object).get(), fieldName, "Lcom/example/time/Duration;");
    auto jValue = ::jni::convert_to_jni(env, fieldValue);
    env->SetObjectField(object.get(), fieldId, jValue.get());
}

template<class Rep, class Period>
JNIEXPORT void set_field_value(
    JNIEnv* env,
    const JniReference<jobject>& object,
    const char* fieldName,
    std::optional<::std::chrono::duration<Rep, Period>> fieldValue ) {

    auto fieldId = env->GetFieldID(get_object_class(env, object).get(), fieldName, "Lcom/example/time/Duration;");
    auto jValue = ::jni::convert_to_jni(env, fieldValue);
    env->SetObjectField(object.get(), fieldId, jValue.get());
}

}
