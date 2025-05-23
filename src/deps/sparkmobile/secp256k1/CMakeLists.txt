# Copyright (c) 2017 The Bitcoin developers

cmake_minimum_required(VERSION 3.10)
project(secp256k1_spark)

SET(ENABLE_MODULE_ECDH 1)
ADD_DEFINITIONS(-DENABLE_MODULE_ECDH=1)
ADD_DEFINITIONS(-DUSE_ENDOMORPHISM=1)
ADD_DEFINITIONS(-DUSE_NUM_NONE=1)
ADD_DEFINITIONS(-DUSE_FIELD_INV_BUILTIN=1)
ADD_DEFINITIONS(-DUSE_SCALAR_INV_BUILTIN=1)

if(BUILD_FOR_SYSTEM_NAME STREQUAL "android")
	# nothing
else()
	ADD_DEFINITIONS(-fPIC)
endif()

# TODO: change this to include when possible
include_directories(. include src/modules/ecdh src)

add_library(secp256k1_spark src/secp256k1.c src/cpp/GroupElement.cpp src/cpp/MultiExponent.cpp src/cpp/Scalar.cpp src/modules/ecdh/main_impl.h include/secp256k1_ecdh.h src/scratch_impl.h src/scratch.h)

# We need to link in GMP
find_package(GMP)
if(GMP_INCLUDE_DIR AND GMP_LIBRARIES)
	target_include_directories(secp256k1 PUBLIC ${GMP_INCLUDE_DIR})
	target_link_libraries(secp256k1_spark ${GMP_LIBRARIES})
	target_compile_definitions(secp256k1_spark
		PUBLIC
			HAVE_LIBGMP
			USE_NUM_GMP
			USE_FIELD_INV_NUM
			USE_SCALAR_INV_BUILTIN
	)
else()
	target_compile_definitions(secp256k1_spark
		PUBLIC
			USE_NUM_NONE
			USE_FIELD_INV_BUILTIN
			USE_SCALAR_INV_BUILTIN
	)
endif()

# We make sure __int128 is defined
include(CheckTypeSize)
check_type_size(__int128 SIZEOF___INT128)
if(SIZEOF___INT128 EQUAL 16)
	target_compile_definitions(secp256k1_spark PUBLIC HAVE___INT128)
else()
	# If we do not support __int128, we should be falling back
	# on 32bits implementations for field and scalar.
endif()

# Detect if we are on a 32 or 64 bits plateform and chose
# scalar and filed implementation accordingly
if(CMAKE_SIZEOF_VOID_P EQUAL 8 AND NOT BUILD_FOR_SYSTEM_NAME STREQUAL "windows")
	# 64 bits implementationr require either __int128 or asm support.
	# TODO: support asm.
	if(NOT SIZEOF___INT128 EQUAL 16)
		message(SEND_ERROR "Compiler does not support __int128")
	endif()

	target_compile_definitions(secp256k1_spark PUBLIC USE_SCALAR_4X64)
	target_compile_definitions(secp256k1_spark PUBLIC USE_FIELD_5X52)
else()
	target_compile_definitions(secp256k1_spark PUBLIC USE_SCALAR_8X32)
	target_compile_definitions(secp256k1_spark PUBLIC USE_FIELD_10X26)
endif()

# TODO: emult static precomputation
# TODO: ecdh module
# TODO: RECOVERY module
TARGET_INCLUDE_DIRECTORIES(secp256k1_spark PUBLIC)
TARGET_LINK_LIBRARIES(secp256k1_spark ${OPENSSL_LIBRARIES})
