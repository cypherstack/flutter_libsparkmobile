
#include "LocaleHandle.h"

#include "Locale.h"
#include <new>
#include <optional>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

FfiOpaqueHandle
library_locale_create_handle(const char* language_code,
                                     const char* country_code,
                                     const char* script_code,
                                     const char* language_tag) {
    auto language_code_optional = language_code != nullptr
        ? std::optional<std::string>(std::string(language_code))
        : std::optional<std::string>();
    auto country_code_optional = country_code != nullptr
        ? std::optional<std::string>(std::string(country_code))
        : std::optional<std::string>();
    auto script_code_optional = script_code != nullptr
        ? std::optional<std::string>(std::string(script_code))
        : std::optional<std::string>();
    auto language_tag_optional = language_tag != nullptr
        ? std::optional<std::string>(std::string(language_tag))
        : std::optional<std::string>();
    return reinterpret_cast<FfiOpaqueHandle>(
        new (std::nothrow) ::Locale(language_code_optional,
                                                               country_code_optional,
                                                               script_code_optional,
                                                               language_tag_optional)
    );
}

void
library_locale_release_handle(FfiOpaqueHandle handle) {
    delete reinterpret_cast<::Locale*>(handle);
}

const char*
library_locale_get_language_code(FfiOpaqueHandle handle) {
    auto& language_code =
        reinterpret_cast<::Locale*>(handle)->language_code;
    return language_code ? (*language_code).c_str() : nullptr;
}

const char*
library_locale_get_country_code(FfiOpaqueHandle handle) {
    auto& country_code =
        reinterpret_cast<::Locale*>(handle)->country_code;
    return country_code ? (*country_code).c_str() : nullptr;
}

const char*
library_locale_get_script_code(FfiOpaqueHandle handle) {
    auto& script_code =
        reinterpret_cast<::Locale*>(handle)->script_code;
    return script_code ? (*script_code).c_str() : nullptr;
}

const char*
library_locale_get_language_tag(FfiOpaqueHandle handle) {
    auto& language_tag =
        reinterpret_cast<::Locale*>(handle)->language_tag;
    return language_tag ? (*language_tag).c_str() : nullptr;
}

#ifdef __cplusplus
}
#endif
