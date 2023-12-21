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
const char* getAddress(unsigned char* keyData, int index, int diversifier, int isTestNet);

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
//FFI_PLUGIN_EXPORT
//struct CIdentifiedCoinData identifyCoin(const unsigned char* serializedCoin, int serializedCoinLength, unsigned char* keyData, int index);

FFI_PLUGIN_EXPORT
struct AggregateCoinData* idAndRecoverCoin(
        const unsigned char* serializedCoin,
        int serializedCoinLength,
        unsigned char* keyData,
        int index,
        unsigned char* context,
        int contextLength,
        int isTestNet
);

/*
 * FFI-friendly wrapper for spark::createSparkMintRecipients.
 *
 * createSparkMintRecipients: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/spark.cpp#L43
 */
FFI_PLUGIN_EXPORT
struct CCRecipientList* cCreateSparkMintRecipients(
        struct CMintedCoinData* outputs,
        int outputsLength,
        unsigned char* serial_context,
        int serial_contextLength,
        int generate);

/*
 * FFI-friendly wrapper for spark::createSparkSpendTransaction.
 *
 * createSparkSpendTransaction: https://github.com/firoorg/sparkmobile/blob/23099b0d9010a970ad75b9cfe05d568d634088f3/src/spark.cpp#L190
 */
FFI_PLUGIN_EXPORT
struct SparkSpendTransactionResult* cCreateSparkSpendTransaction(
        unsigned char* keyData,
        int index,
        struct CRecip* recipients, // This CRecip(ient) is not the same as a CRecipient.
        int recipientsLength,
        struct COutputRecipient* privateRecipients,
        int privateRecipientsLength,
        struct DartSpendCoinData* coins,
        int coinsLength,
        struct CCoverSetData* cover_set_data_all,
        int cover_set_data_allLength,
        struct BlockHashAndId* idAndBlockHashes,
        int idAndBlockHashesLength,
        unsigned char* txHashSig
);

FFI_PLUGIN_EXPORT
struct GetSparkCoinsResult* getCoinsToSpend(
        int64_t spendAmount,
        struct CCSparkMintMeta* coins,
        int coinLength
);

FFI_PLUGIN_EXPORT
struct SelectSparkCoinsResult* selectSparkCoins(
        int64_t required,
        int subtractFeeFromAmount,
        struct CCSparkMintMeta* coins,
        int coinsLength,
        int mintNum
);

FFI_PLUGIN_EXPORT
struct SerializedMintContextResult* serializeMintContext(
        struct DartInputData* inputs,
        int inputsLength
);

FFI_PLUGIN_EXPORT
struct ValidateAddressResult* isValidSparkAddress(
        const char* addressCStr,
        int isTestNet
);

FFI_PLUGIN_EXPORT
const char* hashTags(unsigned char* tags, int tagCount);

#endif //ORG_FIRO_SPARK_DART_INTERFACE_H
