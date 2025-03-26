cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")
project(sparkmobile)

if(BUILD_FOR_SYSTEM_NAME STREQUAL "linux" OR BUILD_FOR_SYSTEM_NAME STREQUAL "windows")
    ADD_DEFINITIONS(-fPIC)
endif()

set(OPENSSL_USE_STATIC_LIBS OFF CACHE BOOL "" FORCE)
set(OPENSSL_USE_STATIC_LIBS TRUE)

SET(OPENSSL_LIBRARIES "ssl" "crypto")

add_subdirectory(secp256k1)

if(BUILD_FOR_SYSTEM_NAME STREQUAL "android")
    # Android exclusive library
    find_library( # Defines the name of the path variable that stores the
            # location of the NDK library.
            log-lib

            # Specifies the name of the NDK library that
            # CMake needs to locate.
            log )
endif()

SET(MY_CUSTOM_COMPILE_FLAGS "-std=c++17")

set_property(SOURCE src/spark.cpp
    src/sparkname.cpp
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

if(BUILD_FOR_SYSTEM_NAME STREQUAL "ios" OR
        BUILD_FOR_SYSTEM_NAME STREQUAL "macos" OR
        BUILD_FOR_SYSTEM_NAME STREQUAL "linux" OR
        BUILD_FOR_SYSTEM_NAME STREQUAL "windows")
    SET(CUSTOM_LIB_TYPE STATIC)
else()
    SET(CUSTOM_LIB_TYPE SHARED)
endif()

add_library(sparkmobile ${CUSTOM_LIB_TYPE}
    src/spark.cpp
    src/sparkname.cpp
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
    target_link_libraries(sparkmobile ${OPENSSL_LIBRARIES} secp256k1_spark Boost::thread ${log-lib})
elseif(BUILD_FOR_SYSTEM_NAME STREQUAL "windows" OR BUILD_FOR_SYSTEM_NAME STREQUAL "macos")
    target_link_libraries(sparkmobile secp256k1_spark Boost::thread ${log-lib})
else()
    target_link_libraries(sparkmobile ${OPENSSL_LIBRARIES} secp256k1_spark Boost::thread)
endif()

add_dependencies(sparkmobile secp256k1_spark)

if(BUILD_FOR_SYSTEM_NAME STREQUAL "ios" OR BUILD_FOR_SYSTEM_NAME STREQUAL "windows" OR BUILD_FOR_SYSTEM_NAME STREQUAL "macos")
    target_include_directories(sparkmobile PUBLIC secp256k1_spark "${SPARK_MISSING_HEADERS_DIR}")
else()
    target_include_directories(sparkmobile PUBLIC secp256k1_spark)
endif()



