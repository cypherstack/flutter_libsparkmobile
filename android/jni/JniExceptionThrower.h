/*

 *
 */

#pragma once

#include "JniReference.h"

namespace jni
{
    class JniExceptionThrower
    {
    public:
        explicit JniExceptionThrower(JNIEnv* jni_env) : m_jni_env(jni_env)
        {
        }

        ~JniExceptionThrower()
        {
            if (m_exception)
            {
                m_jni_env->Throw(static_cast<jthrowable>(m_exception.release()));
            }
        }

        void register_exception(JniReference<jobject> exception)
        {
            m_exception = std::move(exception);
        }
    private:
        JNIEnv* const m_jni_env;
        JniReference<jobject> m_exception;
    };
}
