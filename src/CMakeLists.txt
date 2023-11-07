cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")
project(flutter_libsparkmobile)

set(OPENSSL_USE_STATIC_LIBS OFF CACHE BOOL "" FORCE)

#SET(distribution_DIR /opt/android)
#SET(OPENSSL_ROOT_DIR ${distribution_DIR}/sparkmobile/${ANDROID_ABI})
SET(OPENSSL_ROOT_DIR flutter_libsparkmobile)

SET(OPENSSL_LIBRARIES_DIR "${OPENSSL_ROOT_DIR}/lib")
SET(OPENSSL_INCLUDE_DIR ${OPENSSL_ROOT_DIR}/include)
SET(OPENSSL_LIBRARIES "ssl" "crypto")

LINK_DIRECTORIES(${OPENSSL_LIBRARIES_DIR})

# From flutter_liblelantus...
#add_subdirectory(sparkmobile/secp256k1)

# Attempt to build autotools project with cmake.
#
# See https://stackoverflow.com/questions/5971921/building-a-library-using-autotools-from-cmake
#include(ExternalProject)
#ExternalProject_Add(secp256k1
#        SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/sparkmobile/secp256k1
#        CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/sparkmobile/secp256k1/configure --prefix=${CMAKE_CURRENT_SOURCE_DIR}/sparkmobile/lib
#        BUILD_COMMAND make)

set(secp256k1_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/sparkmobile/secp256k1")

pkg_check_modules(secp256k1 IMPORTED_TARGET libsecp256k1)

if(NOT secp256k1_FOUND)
    set(ENV{CC} ${CMAKE_C_COMPILER})
    set(ENV{CXX} ${CMAKE_CXX_COMPILER})

    # Configure
    execute_process(
            OUTPUT_QUIET
            COMMAND ./autogen.sh --host=${CMAKE_SYSTEM_PROCESSOR} --enable-tools=yes --enable-bindings-cxx --prefix=${CMAKE_CURRENT_SOURCE_DIR}/sparkmobile/lib
            WORKING_DIRECTORY ${secp256k1_SOURCE_DIR}
    )

    # Build
    execute_process(
            OUTPUT_QUIET
            COMMAND make
            WORKING_DIRECTORY ${secp256k1_SOURCE_DIR}
    )

    # Install
    execute_process(
            OUTPUT_QUIET
            COMMAND make install
            WORKING_DIRECTORY ${secp256k1_SOURCE_DIR}
    )

    # After installation, find the package again
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(secp256k1 REQUIRED IMPORTED_TARGET libsecp256k1)
endif()

set_property(SOURCE sparkmobile/src/spark.cpp
        sparkmobile/bitcoin/amount.cpp
        sparkmobile/bitcoin/arith_uint256.cpp
        sparkmobile/bitcoin/script.cpp
        sparkmobile/bitcoin/uint256.cpp
        sparkmobile/bitcoin/utilstrencodings.cpp
        sparkmobile/bitcoin/crypto/aes.cpp
        sparkmobile/bitcoin/crypto/hmac_sha512.cpp
        sparkmobile/bitcoin/crypto/sha256.cpp
        sparkmobile/bitcoin/crypto/sha512.cpp
        sparkmobile/bitcoin/support/cleanse.cpp
        sparkmobile/src/aead.cpp
        sparkmobile/src/bech32.cpp
        sparkmobile/src/bpplus.cpp
        sparkmobile/src/chaum.cpp
        sparkmobile/src/coin.cpp
        sparkmobile/src/f4grumble.cpp
        sparkmobile/src/grootle.cpp
        sparkmobile/src/hash.cpp
        sparkmobile/src/kdf.cpp
        sparkmobile/src/keys.cpp
        sparkmobile/src/mint_transaction.cpp
        sparkmobile/src/params.cpp
        sparkmobile/src/primitives.cpp
        sparkmobile/src/schnorr.cpp
        sparkmobile/src/spend_transaction.cpp
        sparkmobile/src/transcript.cpp
        sparkmobile/src/util.cpp
        sparkmobile/src/utils.cpp
        sparkmobile/src/dart_interface.cpp
        PROPERTY COMPILE_FLAGS "-std=c++17" )

add_library(flutter_libsparkmobile SHARED
        sparkmobile/src/spark.cpp
        sparkmobile/bitcoin/amount.cpp
        sparkmobile/bitcoin/arith_uint256.cpp
        sparkmobile/bitcoin/script.cpp
        sparkmobile/bitcoin/uint256.cpp
        sparkmobile/bitcoin/utilstrencodings.cpp
        sparkmobile/bitcoin/crypto/aes.cpp
        sparkmobile/bitcoin/crypto/hmac_sha512.cpp
        sparkmobile/bitcoin/crypto/sha256.cpp
        sparkmobile/bitcoin/crypto/sha512.cpp
        sparkmobile/bitcoin/support/cleanse.cpp
        sparkmobile/src/aead.cpp
        sparkmobile/src/bech32.cpp
        sparkmobile/src/bpplus.cpp
        sparkmobile/src/chaum.cpp
        sparkmobile/src/coin.cpp
        sparkmobile/src/f4grumble.cpp
        sparkmobile/src/grootle.cpp
        sparkmobile/src/hash.cpp
        sparkmobile/src/kdf.cpp
        sparkmobile/src/keys.cpp
        sparkmobile/src/mint_transaction.cpp
        sparkmobile/src/params.cpp
        sparkmobile/src/primitives.cpp
        sparkmobile/src/schnorr.cpp
        sparkmobile/src/spend_transaction.cpp
        sparkmobile/src/transcript.cpp
        sparkmobile/src/util.cpp
        sparkmobile/src/utils.cpp
        sparkmobile/src/dart_interface.cpp)

target_link_libraries(flutter_libsparkmobile ${OPENSSL_LIBRARIES} #[[secp256k1]])

#add_dependencies(sparkmobile secp256k1)

target_include_directories(flutter_libsparkmobile PUBLIC #[[secp256k1]] ${OPENSSL_INCLUDE_DIR})

target_compile_definitions(flutter_libsparkmobile PUBLIC DART_SHARED_LIB)

set_target_properties(flutter_libsparkmobile PROPERTIES
    PUBLIC_HEADER flutter_libsparkmobile.h
    OUTPUT_NAME "flutter_libsparkmobile"
)
