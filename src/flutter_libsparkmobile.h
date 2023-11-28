
#ifndef ORG_FIRO_SPARK_DART_INTERFACE_H
#define ORG_FIRO_SPARK_DART_INTERFACE_H

#include <stdint.h>

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


/*
 * FFI-friendly wrapper for spark::getAddress.
 */
FFI_PLUGIN_EXPORT
const char* getAddress(const char* keyDataHex, int index, int diversifier, int isTestNet);

/*
FFI_PLUGIN_EXPORT
const char *createFullViewKey(const char* keyData, int index);

FFI_PLUGIN_EXPORT
const char* createIncomingViewKey(const char* keyData, int index);
*/

/*
 * FFI-friendly wrapper for a spark::Coin.
 *
 * A Coin is a type, a key, an index, a value, a memo, and a serial context.  We accept these params
 * as a C struct, deriving the key from the keyData and index.
 */
struct CCoin {
    char type;
    const unsigned char* k;
    int kLength;
    const char* keyData;
    int index;
    uint64_t v;
    const unsigned char* memo;
    int memoLength;
    const unsigned char* serial_context;
    int serial_contextLength;
};

/*
 * FFI-friendly wrapper for a spark::IdentifiedCoinData.
 *
 * An IdentifiedCoinData is a diversifier, encrypted diversifier, value, nonce, and memo.  We accept
 * these params as a C struct.
 */
struct CIdentifiedCoinData {
    uint64_t i;
    const unsigned char* d;
    int dLength;
    uint64_t v;
    const unsigned char* k;
    int kLength;
    const char* memo;
    int memoLength;
};

/*
 * FFI-friendly wrapper for spark::identifyCoin.
 */
FFI_PLUGIN_EXPORT
struct CIdentifiedCoinData identifyCoin(struct CCoin c_struct, const char* keyDataHex, int index);

/*
 * FFI-friendly wrapper for a spark::CRecipient.
 *
 * A CRecipient is a CScript, CAmount, and a bool.  We accept a C-style, FFI-friendly CCRecipient
 * struct in order to construct a C++ CRecipient.  A CScript is constructed from a hex string, a
 * CAmount is just a uint64_t, and the bool will be an int.
 */
struct CCRecipient {
    const unsigned char* pubKey;
    int pubKeyLength;
    uint64_t cAmount;
    int subtractFee;
};

/*
 * FFI-friendly wrapper for a spark::MintedCoinData.
 *
 * A MintedCoinData is a struct that contains an Address, a uint64_t value, and a string memo.  We
 * accept these as a CMintedCoinData from the Dart interface, and convert them to a MintedCoinData
 * struct.
 */
struct CMintedCoinData {
    const char* address;
    uint64_t value;
    const char* memo;
};

struct PubKeyScript {
    unsigned char* bytes;
    int length;
};

/*
 * FFI-friendly wrapper for spark::createSparkMintRecipients.
 */
FFI_PLUGIN_EXPORT
struct CCRecipient* createSparkMintRecipients(
        int numRecipients,
        struct PubKeyScript* pubKeyScripts,
        uint64_t* amounts,
        const char* memo,
        int subtractFee);

#endif //ORG_FIRO_SPARK_DART_INTERFACE_H