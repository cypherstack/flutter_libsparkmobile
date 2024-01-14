# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutter_libsparkmobile_library VERSION 0.0.1)

if(BUILD_FOR_SYSTEM_NAME STREQUAL "linux")
    ADD_DEFINITIONS(-fPIC)
endif()

SET(SPARK_SCRIPTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../scripts")
if(BUILD_FOR_SYSTEM_NAME STREQUAL "windows")
    SET(SPARK_PREBUILD_SCRIPT "prebuild.bat")
else()
    SET(SPARK_PREBUILD_SCRIPT "prebuild.sh")
endif()
execute_process (COMMAND "${SPARK_SCRIPTS_DIR}/${SPARK_PREBUILD_SCRIPT}"
        WORKING_DIRECTORY "${SPARK_SCRIPTS_DIR}")

SET(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")

if(BUILD_FOR_SYSTEM_NAME STREQUAL "macos" OR BUILD_FOR_SYSTEM_NAME STREQUAL "ios" OR BUILD_FOR_SYSTEM_NAME STREQUAL "windows")
    set(CMAKE_CXX_STANDARD 17)
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

#set(BOOST_URL "https://boostorg.jfrog.io/artifactory/main/release/1.71.0/source/boost_1_71_0.zip" CACHE STRING "Boost download URL")
set(BOOST_URL "https://archives.boost.io/release/1.71.0/source/boost_1_71_0.zip" CACHE STRING "Boost download URL")
set(BOOST_URL_SHA256 "85a94ac71c28e59cf97a96714e4c58a18550c227ac8b0388c260d6c717e47a69" CACHE STRING "Boost download URL SHA256 checksum")
add_subdirectory("deps/boost-cmake")

add_subdirectory("deps/openssl-cmake" EXCLUDE_FROM_ALL)

add_subdirectory("deps/sparkmobile")

if(BUILD_FOR_SYSTEM_NAME STREQUAL "macos" OR BUILD_FOR_SYSTEM_NAME STREQUAL "ios")
    set_target_properties(flutter_libsparkmobile PROPERTIES FRAMEWORK TRUE
        FRAMEWORK_VERSION C
        MACOSX_FRAMEWORK_IDENTIFIER com.cypherstack.flutterLibsparkmobile
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
