#ifndef ORG_FIRO_SPARK_DART_INTERFACE_H
#define ORG_FIRO_SPARK_DART_INTERFACE_H

#include <stdint.h>
#include "structs.h"

#ifndef FFI_PLUGIN_EXPORT
#ifdef __cplusplus
#define FFI_PLUGIN_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif
#ifdef _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#endif
#endif

FFI_PLUGIN_EXPORT
const char* getAddress(const char* keyDataHex, int index, int diversifier, int isTestNet);

/*
FFI_PLUGIN_EXPORT
const char *createFullViewKey(const char* keyData, int index);

FFI_PLUGIN_EXPORT
const char* createIncomingViewKey(const char* keyData, int index);
*/

/*
 * FFI-friendly wrapper for spark::identifyCoin.
 *
 * identifyCoin: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/spark.cpp#L400
 */
FFI_PLUGIN_EXPORT
struct CIdentifiedCoinData identifyCoin(const char* serializedCoin, int serializedCoinLength, const char* keyDataHex, int index);

/*
 * FFI-friendly wrapper for spark::createSparkMintRecipients.
 *
 * createSparkMintRecipients: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/spark.cpp#L43
 */
FFI_PLUGIN_EXPORT
struct CCRecipient* createSparkMintRecipients(
        struct CMintedCoinData* outputs,
        int outputsLength,
        const char* serial_context,
        int serial_contextLength,
        int generate);

/*
 * FFI-friendly wrapper for spark::createSparkSpendTransaction.
 *
 * createSparkSpendTransaction: https://github.com/firoorg/sparkmobile/blob/23099b0d9010a970ad75b9cfe05d568d634088f3/src/spark.cpp#L190
 */
FFI_PLUGIN_EXPORT
unsigned char* cCreateSparkSpendTransaction(
        const char* keyDataHex,
        int index,
        struct CRecip* recipients,
        int recipientsLength,
        struct COutputRecipient* privateRecipients,
        int privateRecipientsLength,
        struct CCSparkMintMeta* coins,
        int coinsLength,
        struct CCoverSets* cover_set_data_all,
        int cover_set_data_allLength,
        const char* txHashSig,
        int txHashSigLength,
        uint64_t fee,
        const struct OutputScript* outputScripts,
        int outputScriptsLength
);

#endif //ORG_FIRO_SPARK_DART_INTERFACE_H
