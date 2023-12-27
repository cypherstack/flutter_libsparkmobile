# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutter_libsparkmobile_library VERSION 0.0.1)

SET(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")

if(BUILD_FOR_SYSTEM_NAME STREQUAL "macos")
    set(CMAKE_CXX_STANDARD 17)
elseif(BUILD_FOR_SYSTEM_NAME STREQUAL "ios")
    set(CMAKE_CXX_STANDARD 17)
endif()

add_library(flutter_libsparkmobile SHARED
    "flutter_libsparkmobile.cpp"
    "utils.cpp"
    "transaction.cpp"
)

set(BOOST_URL "https://boostorg.jfrog.io/artifactory/main/release/1.78.0/source/boost_1_78_0.tar.bz"2)
set(BOOST_URL_SHA256 "8681f175d4bdb26c52222665793eef08490d7758529330f98d3b29dd0735bccc")
add_subdirectory("deps/boost-cmake")
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
