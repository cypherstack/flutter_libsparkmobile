cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")
project(sparkmobile)

set(OPENSSL_USE_STATIC_LIBS OFF CACHE BOOL "" FORCE)

SET(distribution_DIR "../../build/${BUILD_FOR_SYSTEM_NAME}")
SET(OPENSSL_ROOT_DIR ${distribution_DIR}/prefix_${ANDROID_ABI})

SET(OPENSSL_LIBRARIES_DIR "${OPENSSL_ROOT_DIR}/lib")
SET(OPENSSL_INCLUDE_DIR ${OPENSSL_ROOT_DIR}/include)
SET(OPENSSL_LIBRARIES "ssl" "crypto")

LINK_DIRECTORIES(${OPENSSL_LIBRARIES_DIR})

add_subdirectory(secp256k1)

if(BUILD_FOR_SYSTEM_NAME STREQUAL "android")
    # Android exclusive library
    find_library( # Defines the name of the path variable that stores the
            # location of the NDK library.
            log-lib

            # Specifies the name of the NDK library that
            # CMake needs to locate.
            log )
    SET(MY_CUSTOM_COMPILE_FLAGS "-L${distribution_DIR}/openssl-1.1.1k/lib/ -std=c++17")
else()
    SET(MY_CUSTOM_COMPILE_FLAGS "-std=c++17")
endif()

set_property(SOURCE src/spark.cpp
    bitcoin/amount.cpp
    bitcoin/arith_uint256.cpp
    bitcoin/script.cpp
    bitcoin/uint256.cpp
    bitcoin/utilstrencodings.cpp
    bitcoin/crypto/aes.cpp
    bitcoin/crypto/hmac_sha512.cpp
    bitcoin/crypto/sha256.cpp
    bitcoin/crypto/sha512.cpp
    bitcoin/support/cleanse.cpp
    src/aead.cpp
    src/bech32.cpp
    src/bpplus.cpp
    src/chaum.cpp
    src/coin.cpp
    src/f4grumble.cpp
    src/grootle.cpp
    src/hash.cpp
    src/kdf.cpp
    src/keys.cpp
    src/mint_transaction.cpp
    src/params.cpp
    src/primitives.cpp
    src/schnorr.cpp
    src/spend_transaction.cpp
    src/transcript.cpp
    src/util.cpp
    PROPERTY COMPILE_FLAGS ${MY_CUSTOM_COMPILE_FLAGS} )

add_library(sparkmobile SHARED
    src/spark.cpp
    bitcoin/amount.cpp
    bitcoin/arith_uint256.cpp
    bitcoin/script.cpp
    bitcoin/uint256.cpp
    bitcoin/utilstrencodings.cpp
    bitcoin/crypto/aes.cpp
    bitcoin/crypto/hmac_sha512.cpp
    bitcoin/crypto/sha256.cpp
    bitcoin/crypto/sha512.cpp
    bitcoin/support/cleanse.cpp
    src/aead.cpp
    src/bech32.cpp
    src/bpplus.cpp
    src/chaum.cpp
    src/coin.cpp
    src/f4grumble.cpp
    src/grootle.cpp
    src/hash.cpp
    src/kdf.cpp
    src/keys.cpp
    src/mint_transaction.cpp
    src/params.cpp
    src/primitives.cpp
    src/schnorr.cpp
    src/spend_transaction.cpp
    src/transcript.cpp
    src/util.cpp)

if(BUILD_FOR_SYSTEM_NAME STREQUAL "android")
    target_link_libraries(sparkmobile ${OPENSSL_LIBRARIES} secp256k1_spark ${log-lib})
else()
    target_link_libraries(sparkmobile ${OPENSSL_LIBRARIES} secp256k1_spark)
endif()

add_dependencies(sparkmobile secp256k1_spark)

target_include_directories(sparkmobile PUBLIC secp256k1_spark ${OPENSSL_INCLUDE_DIR})
