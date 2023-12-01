#!/bin/sh

export MACOS_SCRIPTS_DIR=`pwd`
export PROJECT_ROOT_DIR="${MACOS_SCRIPTS_DIR}/../.."
export MOBILE_LIB_ROOT="${PROJECT_ROOT_DIR}/src"
export EXTERNAL_MACOS_DIR="${MOBILE_LIB_ROOT}/build/macos"
export EXTERNAL_MACOS_SOURCE_DIR=${EXTERNAL_MACOS_DIR}/sources
export EXTERNAL_MACOS_LIB_DIR=${EXTERNAL_MACOS_DIR}/lib
export EXTERNAL_MACOS_INCLUDE_DIR=${EXTERNAL_MACOS_DIR}/include

OPEN_SSL_DIR_NAME="OpenSSL"
OPEN_SSL_x86_64_DIR_NAME="${OPEN_SSL_DIR_NAME}-x86_64"
OPEN_SSL_ARM_DIR_NAME="${OPEN_SSL_DIR_NAME}-arm"
OPEN_SSL_X86_64_DIR_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/${OPEN_SSL_x86_64_DIR_NAME}"
OPEN_SSL_ARM_DIR_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/${OPEN_SSL_ARM_DIR_NAME}"

build_openssl_init_common() {
	DIR=$1
	# Use 1.1.1s becasue of https://github.com/openssl/openssl/issues/18720
	OPENSSL_VERSION="1.1.1s"

	echo "============================ OpenSSL ============================"

	cd $EXTERNAL_MACOS_SOURCE_DIR
	curl -O https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
	tar -xvzf openssl-$OPENSSL_VERSION.tar.gz
	rm -rf $DIR
	rm -rf $OPEN_SSL_DIR_PATH
	mv openssl-$OPENSSL_VERSION $DIR
	tar -xvzf openssl-$OPENSSL_VERSION.tar.gz
	mv openssl-$OPENSSL_VERSION $OPEN_SSL_ARM_DIR_NAME
}

build_openssl_init_arm64() {
	DIR=$OPEN_SSL_ARM_DIR_PATH
	build_openssl_init_common ${DIR}
}

build_openssl_init_x86_64() {
	DIR=$OPEN_SSL_X86_64_DIR_PATH
	build_openssl_init_common ${DIR}
}

build_openssl_compile_common() {
	ARCH=$1
	DIR=""
	XARCH=""
	case $ARCH in
		arm64)
			DIR=$OPEN_SSL_ARM_DIR_PATH
			XARCH="darwin64-arm64-cc";;
		x86_64)
			DIR=$OPEN_SSL_X86_64_DIR_PATH
			XARCH="darwin64-x86_64-cc";;
	esac

	echo "Build OpenSSL for ${ARCH}"
	cd $DIR
	./Configure $XARCH
	make

}

build_openssl_compile_arm64() {
	ARCH=arm64
	build_openssl_compile_common "${ARCH}"
}

build_openssl_compile_x86_64() {
	ARCH=x86_64
	build_openssl_compile_common "${ARCH}"
}

build_openssl_install_common() {
	DIR=$1
	cp -R ${DIR}/include/* "${EXTERNAL_MACOS_INCLUDE_DIR}/"
	cp -R ${DIR}/libcrypto.a ${EXTERNAL_MACOS_LIB_DIR}/libcrypto.a
	cp -R ${DIR}/libssl.a ${EXTERNAL_MACOS_LIB_DIR}/libssl.a
}

build_openssl_install_arm64() {
	build_openssl_install_common "${OPEN_SSL_ARM_DIR_PATH}"
}

build_openssl_install_x86_64() {
	build_openssl_install_common "${OPEN_SSL_X86_64_DIR_PATH}"
}

build_openssl_install_universal() {
	OPEN_SSL_DIR_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/${OPEN_SSL_DIR_NAME}"
	mv ${OPEN_SSL_ARM_DIR_PATH}/include/* $OPEN_SSL_DIR_PATH/include
	build_openssl_install_common "${OPEN_SSL_DIR_PATH}"
}

build_openssl_arm64() {
	build_openssl_init_arm64
	build_openssl_compile_arm64
	build_openssl_install_arm64
}

build_openssl_x86_64() {
	build_openssl_init_x86_64
	build_openssl_compile_x86_64
	build_openssl_install_x86_64
}

build_openssl_combine() {
	OPEN_SSL_DIR_PATH="${EXTERNAL_MACOS_SOURCE_DIR}/${OPEN_SSL_DIR_NAME}"
	echo "Create universal bin"
	mkdir -p $OPEN_SSL_DIR_PATH/include
	lipo -create ${OPEN_SSL_ARM_DIR_PATH}/libcrypto.a ${OPEN_SSL_X86_64_DIR_PATH}/libcrypto.a -output ${OPEN_SSL_DIR_PATH}/libcrypto.a
	lipo -create ${OPEN_SSL_ARM_DIR_PATH}/libssl.a ${OPEN_SSL_X86_64_DIR_PATH}/libssl.a -output ${OPEN_SSL_DIR_PATH}/libssl.a
}

build_openssl_universal() {
	build_openssl_init_arm64
	build_openssl_compile_arm64
	build_openssl_init_x86_64
	build_openssl_compile_x86_64
	build_openssl_combine
	build_openssl_install_universal
}