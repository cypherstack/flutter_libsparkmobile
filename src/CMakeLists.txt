# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutter_libsparkmobile_library VERSION 0.0.1)

SET(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")

if(BUILD_FOR_SYSTEM_NAME STREQUAL "macos" OR BUILD_FOR_SYSTEM_NAME STREQUAL "windows")
    set(CMAKE_CXX_STANDARD 17)
elseif(BUILD_FOR_SYSTEM_NAME STREQUAL "ios")
    set(CMAKE_CXX_STANDARD 17)
endif()

if(BUILD_FOR_SYSTEM_NAME STREQUAL "windows")
    SET(OPENSSL_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/build/${BUILD_FOR_SYSTEM_NAME}")
elseif(BUILD_FOR_SYSTEM_NAME STREQUAL "macos" OR BUILD_FOR_SYSTEM_NAME STREQUAL "ios")
    SET(OPENSSL_ROOT_DIR "${CMAKE_SOURCE_DIR}/build/${BUILD_FOR_SYSTEM_NAME}")
else()
    SET(OPENSSL_ROOT_DIR "${CMAKE_SOURCE_DIR}/build/${BUILD_FOR_SYSTEM_NAME}/prefix_${ANDROID_ABI}")
endif()

if(BUILD_FOR_SYSTEM_NAME STREQUAL "macos" OR BUILD_FOR_SYSTEM_NAME STREQUAL "ios")
    SET(SPARK_MISSING_HEADERS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/missing_headers/darwin")
elseif(BUILD_FOR_SYSTEM_NAME STREQUAL "windows")
    SET(SPARK_MISSING_HEADERS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/missing_headers/windows")
endif()

add_library(flutter_libsparkmobile SHARED
    "flutter_libsparkmobile.cpp"
    "utils.cpp"
    "transaction.cpp"
)

set(BOOST_URL "https://boostorg.jfrog.io/artifactory/main/release/1.71.0/source/boost_1_71_0.zip")
set(BOOST_URL_SHA256 "85a94ac71c28e59cf97a96714e4c58a18550c227ac8b0388c260d6c717e47a69")
add_subdirectory("deps/boost-cmake")

set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/install CACHE PATH comment FORCE)
add_subdirectory("deps/openssl-cmake")

add_subdirectory("deps/sparkmobile")

if(BUILD_FOR_SYSTEM_NAME STREQUAL "macos" OR BUILD_FOR_SYSTEM_NAME STREQUAL "ios")
    set_target_properties(flutter_libsparkmobile PROPERTIES FRAMEWORK TRUE
        FRAMEWORK_VERSION C
        MACOSX_FRAMEWORK_IDENTIFIER com.cypherstack.flutter_libsparkmobile
        # "current version" in semantic format in Mach-O binary file
        VERSION 16.4.0
        # "compatibility version" in semantic format in Mach-O binary file
        SOVERSION 1.0.0
        PUBLIC_HEADER flutter_libsparkmobile.h
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
    )
    target_compile_options(flutter_libsparkmobile PUBLIC -fembed-bitcode)
else()
    set_target_properties(flutter_libsparkmobile PROPERTIES
        PUBLIC_HEADER flutter_libsparkmobile.h
        OUTPUT_NAME "flutter_libsparkmobile"
    )
endif()

target_link_libraries(flutter_libsparkmobile sparkmobile)

target_compile_definitions(flutter_libsparkmobile PUBLIC DART_SHARED_LIB)
