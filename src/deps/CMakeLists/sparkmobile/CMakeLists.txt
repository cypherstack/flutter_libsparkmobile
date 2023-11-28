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
    PROPERTY COMPILE_FLAGS "-std=c++17" )

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

target_link_libraries(sparkmobile ${OPENSSL_LIBRARIES} secp256k1_spark)

add_dependencies(sparkmobile secp256k1_spark)

target_include_directories(sparkmobile PUBLIC secp256k1_spark ${OPENSSL_INCLUDE_DIR})