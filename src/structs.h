#ifndef ORG_FIRO_SPARK_DART_STRUCTS_H
#define ORG_FIRO_SPARK_DART_STRUCTS_H

#include <stdint.h>

//#ifdef __cplusplus
//extern C {
//#endif

/*
 * FFI-friendly wrapper for a spark::Coin.
 *
 * Coin: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/coin.h#L66
 */
struct CCoin {
    char type;
    const unsigned char *k;
    int kLength;
    const char *address;
    uint64_t v;
    const unsigned char *memo;
    int memoLength;
    const unsigned char *serial_context;
    int serial_contextLength;
};

/*
 * FFI-friendly wrapper for a spark::IdentifiedCoinData.
 *
 * IdentifiedCoinData: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/coin.h#L19
 */
struct CIdentifiedCoinData {
    uint64_t i;
    const unsigned char *d;
    int dLength;
    uint64_t v;
    const unsigned char *k;
    int kLength;
    const char *memo;
    int memoLength;
};

/*
 * FFI-friendly wrapper for a spark::CRecipient.
 *
 * CRecipient: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/include/spark.h#L27
 */
struct CCRecipient {
    unsigned char *pubKey;
    int pubKeyLength;
    uint64_t cAmount;
    int subtractFee;
};

struct CCRecipientList {
    struct CCRecipient* list;
    int length;
};

/*
 * FFI-friendly wrapper for a spark::MintedCoinData.
 *
 * MintedCoinData: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/mint_transaction.h#L12
 */
struct CMintedCoinData {
    const char *address;
    uint64_t value;
    const char *memo;
};

struct PubKeyScript {
    unsigned char *bytes;
    int length;
};


/*
 * FFI-friendly wrapper for a std::pair<CAmount, bool>.
 *
 * Note this is an ambiguation of a spark::CRecipient.  This CRecip(ient) is just a wrapper for a
 * CAmount and bool pair, and is not the same as the spark::CRecipient struct above, which gets
 * wrapped for us as a CCRecipient and is unrelated to this struct.
 *
 * See https://github.com/firoorg/sparkmobile/blob/23099b0d9010a970ad75b9cfe05d568d634088f3/src/spark.cpp#L190
 */
struct CRecip {
    uint64_t amount;
    int subtractFee;
};

/*
 * FFI-friendly wrapper for a spark::OutputCoinData.
 *
 * OutputCoinData: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/spend_transaction.h#L33
 */
struct COutputCoinData {
    const char *address;
    uint64_t value;
    const char *memo;
};

/*
 * FFI-friendly wrapper for a <spark::OutputCoinData, bool>.
 *
 * See https://github.com/firoorg/sparkmobile/blob/23099b0d9010a970ad75b9cfe05d568d634088f3/src/spark.cpp#L195
 */
struct COutputRecipient {
    struct COutputCoinData* output;
    int subtractFee;
};

struct CCDataStream {
    unsigned char *data;
    int length;
};

/*
 * FFI-friendly wrapper for a spark::CSparkMintMeta.
 *
 * CSparkMintMeta: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/primitives.h#L9
 */
struct CCSparkMintMeta {
    int height;
    int id;
    int isUsed;
    unsigned char *txid;
    uint64_t i; // Diversifier.
    const unsigned char *d; // Encrypted diversifier.
    int dLength;
    uint64_t v; // Value.
    const unsigned char *k; // Nonce.
    int kLength;
    const char *memo;
    int memoLength;
    unsigned char *serial_context;
    int serial_contextLength;
    char type;
    unsigned char* serializedCoin;
    int serializedCoinLength;
};

struct SelectedSparkSpendCoins {
    struct CCSparkMintMeta* list;
    int length;

    int64_t changeToMint;
};

/*
 * FFI-friendly wrapper for a spark::CoverSetData.
 *
 * CoverSetData: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/spend_transaction.h#L28
 */
struct CCoverSetData {
    struct CCDataStream *cover_set; // vs. struct CCoin* cover_set;
    int cover_setLength;
    const unsigned char *cover_set_representation;
    int cover_set_representationLength;

    int setId;
};



struct OutputScript {
    unsigned char *bytes;
    int length;
};

/*
 * Aggregate data structure to handle passing spark mint/spend data across FFI
 */
struct AggregateCoinData {
    char type;
    uint64_t diversifier;
    uint64_t value;
    char *address;
    char *memo;
    char *lTagHash;

    unsigned char *encryptedDiversifier;
    int encryptedDiversifierLength;

    unsigned char *serial;
    int serialLength;

    unsigned char *nonce;
    int nonceLength;
};

/*
 * Aggregate data structure to handle passing spark spend data across FFI.
 *
 * Contains the serialized transaction or the error message if isError is true.
 */
struct SparkSpendTransactionResult {
    unsigned char *data;
    int dataLength;

    struct OutputScript* outputScripts;
    int outputScriptsLength;

    int fee;

    int isError;
};

//#ifdef __cplusplus
//}
//#endif

#endif //ORG_FIRO_SPARK_DART_STRUCTS_H
