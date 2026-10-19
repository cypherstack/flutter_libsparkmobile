#include "flutter_libsparkmobile.h"
#include "utils.h"
#include "deps/sparkmobile/include/spark.h"
#include "deps/sparkmobile/src/sparkname.h"
#include "deps/sparkmobile/bitcoin/hash.h"
#include "deps/sparkmobile/bitcoin/uint256.h"
#include "structs.h"
#include "transaction.h"
#include "deps/sparkmobile/bitcoin/script.h"  // For CScript.
#include "deps/sparkmobile/bitcoin/serialize.h"
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <memory>
#include <utility>

namespace {

// The reason for the most recent failed call on this thread. Dart reads it
// synchronously after the failing call, so a per-thread buffer needs no locking.
thread_local char lastError[512] = {};

void setLastError(const char* message) {
    if (!message || !*message) message = "Unknown native error";
    strncpy(lastError, message, sizeof(lastError) - 1);
    lastError[sizeof(lastError) - 1] = '\0';
}

// Records a failure reason; converts to any pointer return type.
std::nullptr_t fail(const char* message) {
    setLastError(message);
    return nullptr;
}

// Records the exception being handled; only valid inside a catch block.
std::nullptr_t failWithException() {
    try {
        throw;
    } catch (const std::exception& e) {
        setLastError(e.what());
    } catch (...) {
        setLastError("Unknown native exception");
    }
    return nullptr;
}

template<typename T>
T* allocate(size_t count = 1) {
    auto* result = static_cast<T*>(calloc(count ? count : 1, sizeof(T)));
    if (!result) throw std::bad_alloc();
    return result;
}

unsigned char* copyBytes(const void* source, size_t length) {
    auto* result = static_cast<unsigned char*>(malloc(length ? length : 1));
    if (!result) throw std::bad_alloc();
    if (length) memcpy(result, source, length);
    return result;
}

char* copyString(const std::string& value) {
    auto* result = static_cast<char*>(malloc(value.size() + 1));
    if (!result) throw std::bad_alloc();
    memcpy(result, value.data(), value.size());
    result[value.size()] = '\0';
    return result;
}

// The secp256k1 field prime, big-endian, for rejecting non-canonical x coordinates.
constexpr unsigned char fieldPrimeBytes[32] = {
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xfe, 0xff, 0xff, 0xfc, 0x2f,
};

// A serialized tag is x (32 bytes), a 0/1 oddness byte, and a 0/1 infinity byte.
bool isCanonicalTag(const unsigned char* tag) {
    return memcmp(tag, fieldPrimeBytes, 32) < 0 && tag[32] <= 1 && tag[33] == 0;
}

bool isHexCoordinate(const char* value) {
    if (!value || !*value) return false;
    if (strspn(value, "0123456789abcdefABCDEF") != strlen(value)) return false;
    while (*value == '0') ++value;
    const size_t length = strlen(value);
    if (length != 64) return length < 64;
    static constexpr char fieldPrime[] =
        "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f";
    for (size_t i = 0; i < length; ++i) {
        const char digit = value[i] | 0x20; // Fold validated ASCII hex to lowercase.
        if (digit != fieldPrime[i]) return digit < fieldPrime[i];
    }
    return false;
}

void freeCoinData(AggregateCoinData* data) {
    if (!data) return;
    free(data->address);
    free(data->memo);
    free(data->lTagHash);
    free(data->encryptedDiversifier);
    free(data->nonceHex);
    free(data->serial);
    free(data);
}

void freeRecipients(CCRecipientList* data) {
    if (!data) return;
    if (data->list) {
        for (int i = 0; i < data->length; ++i) free(data->list[i].pubKey);
    }
    free(data->list);
    free(data);
}

void freeSpendResult(SparkSpendTransactionResult* data) {
    if (!data) return;
    if (data->usedCoins) {
        for (int i = 0; i < data->usedCoinsLength; ++i) {
            auto& coin = data->usedCoins[i];
            if (coin.serializedCoin) free(coin.serializedCoin->data);
            if (coin.serializedCoinContext) free(coin.serializedCoinContext->data);
            free(coin.serializedCoin);
            free(coin.serializedCoinContext);
        }
    }
    if (data->outputScripts) {
        for (int i = 0; i < data->outputScriptsLength; ++i) free(data->outputScripts[i].bytes);
    }
    free(data->usedCoins);
    free(data->outputScripts);
    free(data->data);
    free(data);
}

}

using namespace spark;

#ifdef __cplusplus
extern "C" {
#endif

/*
 * FFI-friendly wrapper for spark::getAddress.
 *
 * getAddress: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/spark.cpp#L388
 */
FFI_PLUGIN_EXPORT
const char* getAddress(unsigned char* keyData, int index, int diversifier, int isTestNet) {
    try {
        if (!keyData || index < 0 || diversifier < 0) {
            return fail("Private key data, index, and diversifier are required");
        }
        spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);
        spark::FullViewKey fullViewKey(spendKey);
        return getAddressFromFullViewKey(&fullViewKey, index, diversifier, isTestNet);
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
const char* getAddressFromFullViewKey(void* fullViewKeyVoid, int index, int diversifier, int isTestNet) {
    try {
        if (!fullViewKeyVoid || index < 0 || diversifier < 0) {
            return fail("Full view key, index, and diversifier are required");
        }
        spark::IncomingViewKey incomingViewKey(*static_cast<spark::FullViewKey*>(fullViewKeyVoid));
        spark::Address address(incomingViewKey, static_cast<uint64_t>(diversifier));

        std::string encodedAddress = address.encode(isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);
        return copyString(encodedAddress);
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
SparkAddressOwnershipProofResult* createSparkAddressOwnershipProof(
        const unsigned char* message,
        int messageLength,
        unsigned char* spendKeyData,
        int spendKeyIndex,
        int diversifier
) {
    SparkAddressOwnershipProofResult* result =
        static_cast<SparkAddressOwnershipProofResult*>(malloc(sizeof(SparkAddressOwnershipProofResult)));
    if (!result) return fail("Out of memory");

    result->proof = nullptr;
    result->proofLength = 0;
    result->error = nullptr;

    try {
        if (messageLength < 0 || (messageLength > 0 && !message)) {
            throw std::invalid_argument("Invalid message");
        }
        if (!spendKeyData || spendKeyIndex < 0 || diversifier < 0) {
            throw std::invalid_argument("Invalid Spark key parameters");
        }

        const std::string messageString = messageLength == 0
            ? std::string()
            : std::string(
                reinterpret_cast<const char*>(message),
                static_cast<size_t>(messageLength));
        CHashWriter messageHash(SER_GETHASH, 0);
        messageHash << std::string("Zcoin Signed Message:\n") << messageString;

        Scalar messageScalar;
        messageScalar.SetHex(messageHash.GetHash().GetHex());

        spark::SpendKey spendKey = createSpendKeyFromData(spendKeyData, spendKeyIndex);
        spark::FullViewKey fullViewKey(spendKey);
        spark::IncomingViewKey incomingViewKey(fullViewKey);
        spark::Address address(incomingViewKey, static_cast<uint64_t>(diversifier));

        spark::OwnershipProof proof;
        address.prove_own(messageScalar, spendKey, incomingViewKey, proof);

        CDataStream proofStream(SER_NETWORK, PROTOCOL_VERSION);
        proofStream << proof;

        result->proofLength = static_cast<int>(proofStream.size());
        result->proof = static_cast<unsigned char*>(malloc(proofStream.size()));
        if (!result->proof) {
            free(result);
            return fail("Out of memory");
        }
        memcpy(result->proof, proofStream.data(), proofStream.size());
    } catch (const std::exception& e) {
        result->error = static_cast<char*>(malloc(strlen(e.what()) + 1));
        if (!result->error) {
            free(result);
            return fail("Out of memory");
        }
        strcpy(result->error, e.what());
    } catch (...) {
        free(result->proof);
        free(result);
        return failWithException();
    }

    return result;
}

FFI_PLUGIN_EXPORT
int verifySparkAddressOwnershipProof(
        const unsigned char* message,
        int messageLength,
        const char* encodedAddress,
        const unsigned char* proofData,
        int proofLength,
        int isTestNet
) {
    try {
        spark::OwnershipProof proof;
        if (messageLength < 0 || (messageLength > 0 && !message) ||
            !encodedAddress || !proofData ||
            proofLength != static_cast<int>(proof.memoryRequired())) {
            return 0;
        }

        spark::Address address;
        if (address.decode(encodedAddress) != (isTestNet
                ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET)) {
            return 0;
        }

        const char* bytes = reinterpret_cast<const char*>(proofData);
        CDataStream stream(bytes, bytes + proofLength, SER_NETWORK, PROTOCOL_VERSION);
        stream >> proof;
        // Reject alternate encodings as well as truncated or trailing data.
        CDataStream canonical(SER_NETWORK, PROTOCOL_VERSION);
        canonical << proof;
        if (canonical.size() != static_cast<size_t>(proofLength) ||
            memcmp(canonical.data(), proofData, proofLength) != 0) {
            return 0;
        }

        const std::string messageString = messageLength == 0
            ? std::string()
            : std::string(reinterpret_cast<const char*>(message), messageLength);
        CHashWriter messageHash(SER_GETHASH, 0);
        messageHash << std::string("Zcoin Signed Message:\n") << messageString;
        Scalar messageScalar;
        messageScalar.SetHex(messageHash.GetHash().GetHex());
        return address.verify_own(messageScalar, proof) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

FFI_PLUGIN_EXPORT
void* getFullViewKeyFromPrivateKeyData(unsigned char* keyData, int index) {
    try {
        if (!keyData || index < 0) return fail("Private key data and index are required");
        spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);
        return new spark::FullViewKey(spendKey);
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
void* deserializeFullViewKey(unsigned char* keyData, int keyDataLength) {
    try {
        if (!keyData || keyDataLength <= 0) return fail("Full view key data must not be empty");
        auto fullViewKey = std::make_unique<spark::FullViewKey>(spark::Params::get_default());
        if (GetSerializeSize(*fullViewKey, SER_NETWORK, PROTOCOL_VERSION) != static_cast<size_t>(keyDataLength)) {
            return fail("Full view key has an unexpected length");
        }
        CDataStream stream(SER_NETWORK, PROTOCOL_VERSION);
        stream.write(reinterpret_cast<char*>(keyData), keyDataLength);
        stream >> *fullViewKey;
        return fullViewKey.release();
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
unsigned char* serializeFullViewKey(void* fullViewKeyVoid, int* serializedSize) {
    if (!serializedSize) return fail("Serialized size output is required");
    *serializedSize = 0;
    try {
        if (!fullViewKeyVoid) return fail("Full view key is required");
        CDataStream stream(SER_NETWORK, PROTOCOL_VERSION);
        stream << *static_cast<spark::FullViewKey*>(fullViewKeyVoid);
        auto* result = copyBytes(stream.data(), stream.size());
        *serializedSize = stream.size();
        return result;
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
void deleteFullViewKey(void* fullViewKey) {
    delete static_cast<spark::FullViewKey*>(fullViewKey);
}

FFI_PLUGIN_EXPORT
AggregateCoinData* idAndRecoverCoinByFullViewKey(
        const unsigned char* serializedCoin,
        int serializedCoinLength,
        void* fullViewKeyVoid,
        unsigned char* context,
        int contextLength,
        int isTestNet) {
    try {
        if (serializedCoinLength < 0 || (serializedCoinLength > 0 && !serializedCoin) || !fullViewKeyVoid ||
            contextLength < 0 || (contextLength > 0 && !context)) {
            return fail("Serialized coin, full view key, and context are required");
        }
        spark::FullViewKey* fullViewKey = static_cast<spark::FullViewKey*>(fullViewKeyVoid);

        std::vector<unsigned char> contextVec;
        if (contextLength) contextVec.assign(context, context + contextLength);

        // Derive the incoming view key from the full view key
        spark::IncomingViewKey incomingViewKey(*fullViewKey);

        spark::Coin coin;
        spark::IdentifiedCoinData identifiedCoinData;
        try {
            coin = deserializeCoin(serializedCoin, serializedCoinLength);
            coin.setSerialContext(contextVec);
            identifiedCoinData = coin.identify(incomingViewKey);
        } catch (const std::bad_alloc&) {
            throw;
        } catch (const std::exception&) {
            // A coin that does not parse or decrypt with this key is not ours,
            // so return no result without recording an error.
            lastError[0] = '\0';
            return nullptr;
        }

        spark::RecoveredCoinData data = coin.recover(*fullViewKey, identifiedCoinData);

        spark::Address address = getAddress(incomingViewKey, identifiedCoinData.i);
        std::string addressString = address.encode(isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);

        std::unique_ptr<AggregateCoinData, decltype(&freeCoinData)> result(
            allocate<AggregateCoinData>(), freeCoinData);

        result->type = coin.type;
        result->diversifier = identifiedCoinData.i;
        result->value = identifiedCoinData.v;

        result->address = copyString(addressString);

        result->memoLength = identifiedCoinData.memo.size();
        result->memo = copyString(identifiedCoinData.memo);

        uint256 lTagHash = primitives::GetLTagHash(data.T);
        result->lTagHash = copyString(lTagHash.GetHex());

        result->encryptedDiversifier = copyBytes(identifiedCoinData.d.data(), identifiedCoinData.d.size());
        result->encryptedDiversifierLength = identifiedCoinData.d.size();

        std::string nonceHex = identifiedCoinData.k.GetHex();
        result->nonceHexLength = nonceHex.size();
        result->nonceHex = copyString(nonceHex);

        std::string serial = data.s.GetHex();
        result->serial = copyBytes(serial.data(), serial.size());
        result->serialLength = serial.size();

        return result.release();
    } catch (...) {
        return failWithException();
    }
}

/*
 * FFI-friendly wrapper for spark::createSparkMintRecipients.
 *
 * createSparkMintRecipients: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/spark.cpp#L43
 */
FFI_PLUGIN_EXPORT
CCRecipientList* cCreateSparkMintRecipients(
    struct CMintedCoinData* cOutputs,
    int outputsLength,
    unsigned char* serial_context,
    int serial_contextLength,
    int generate
) {
    try {
        if (outputsLength < 0 || (outputsLength > 0 && !cOutputs) ||
            serial_contextLength < 0 || (serial_contextLength > 0 && !serial_context)) {
            return fail("Mint outputs and serial context are required");
        }
        std::vector<spark::MintedCoinData> outputs;
        outputs.reserve(outputsLength);
        for (int i = 0; i < outputsLength; i++) {
            if (!cOutputs[i].address || cOutputs[i].memoLength < 0 ||
                (cOutputs[i].memoLength > 0 && !cOutputs[i].memo)) {
                return fail("Each mint output needs an address and a valid memo length");
            }
            spark::MintedCoinData data;
            if (cOutputs[i].memoLength) data.memo.assign(cOutputs[i].memo, cOutputs[i].memoLength);
            data.address = decodeAddress(cOutputs[i].address);
            data.v = cOutputs[i].value;
            outputs.push_back(std::move(data));
        }

        std::vector<unsigned char> serialVec;
        if (serial_contextLength) serialVec.assign(serial_context, serial_context + serial_contextLength);
        std::vector<CRecipient> recipients = createSparkMintRecipients(outputs, serialVec, generate);

        std::unique_ptr<CCRecipientList, decltype(&freeRecipients)> data(
            allocate<CCRecipientList>(), freeRecipients);
        data->length = recipients.size();
        data->list = allocate<CCRecipient>(recipients.size());
        for (int i = 0; i < data->length; i++) {
            data->list[i].cAmount = recipients[i].amount;
            data->list[i].subtractFee = recipients[i].subtractFeeFromAmount;
            data->list[i].pubKeyLength = recipients[i].pubKey.size();
            data->list[i].pubKey = copyBytes(
                recipients[i].pubKey.empty() ? nullptr : &recipients[i].pubKey[0], recipients[i].pubKey.size());
        }
        return data.release();
    } catch (...) {
        return failWithException();
    }
}

/*
 * FFI-friendly wrapper for spark::createSparkSpendTransaction.
 *
 * createSparkSpendTransaction: https://github.com/firoorg/sparkmobile/blob/23099b0d9010a970ad75b9cfe05d568d634088f3/src/spark.cpp#L190
 */
FFI_PLUGIN_EXPORT
SparkSpendTransactionResult* cCreateSparkSpendTransaction(
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
    unsigned char* txHashSig,
    int additionalTxSize,
    int spendVersion,
    const unsigned char* extensionCommitment
) {
    try {
        // Derive the keys from the key data and index.
        spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);
        spark::FullViewKey fullViewKey(spendKey);
        spark::IncomingViewKey incomingViewKey(fullViewKey);

        // Convert CRecipient* recipients to std::vector<std::pair<CAmount, bool>> cppRecipients.
        std::vector<std::pair<CAmount, bool>> cppRecipients;
        cppRecipients.reserve(recipientsLength);
        for (int i = 0; i < recipientsLength; i++) {
            cppRecipients.emplace_back(recipients[i].amount, recipients[i].subtractFee);
        }

        // Convert COutputRecipient* privateRecipients to std::vector<std::pair<spark::OutputCoinData, bool>> cppPrivateRecipients.
        std::vector<std::pair<spark::OutputCoinData, bool>> cppPrivateRecipients;
        cppPrivateRecipients.reserve(privateRecipientsLength);
        for (int i = 0; i < privateRecipientsLength; i++) {
            spark::OutputCoinData outputCoinData;
            outputCoinData.memo = std::string(privateRecipients[i].output->memo, privateRecipients[i].output->memoLength);
            outputCoinData.v = (uint64_t)privateRecipients[i].output->value;
            std::string addrString(privateRecipients[i].output->address, privateRecipients[i].output->addressLength);
            outputCoinData.address = decodeAddress(addrString);
            cppPrivateRecipients.emplace_back(std::move(outputCoinData), privateRecipients[i].subtractFee);
        }

        // Convert CCSparkMintMeta* serializedMintMetas to std::list<CSparkMintMeta> cppCoins.
        std::list<CSparkMintMeta> cppCoins;
        for (int i = 0; i < coinsLength; i++) {
            spark::Coin coin = deserializeCoin(coins[i].serializedCoin->data, coins[i].serializedCoin->length);
            std::vector<unsigned char> contextVec(coins[i].serializedCoinContext->data, coins[i].serializedCoinContext->data + coins[i].serializedCoinContext->length);
            coin.setSerialContext(contextVec);
            CSparkMintMeta meta = getMetadata(coin, incomingViewKey);
            meta.nId = coins[i].groupId;
            meta.nHeight = coins[i].height;
            meta.coin = std::move(coin);
            cppCoins.push_back(std::move(meta));
        }

        std::unordered_map<uint64_t, spark::CoverSetData> cppCoverSetDataAll;
        cppCoverSetDataAll.reserve(cover_set_data_allLength);
        for (int i = 0; i < cover_set_data_allLength; i++) {
            spark::CoverSetData cppCoverSetData;
            cppCoverSetData.cover_set.reserve(cover_set_data_all[i].cover_setLength);
            for (int j = 0; j < cover_set_data_all[i].cover_setLength; j++) {
                spark::Coin coin = deserializeCoin(cover_set_data_all[i].cover_set[j].data, cover_set_data_all[i].cover_set[j].length);
                cppCoverSetData.cover_set.push_back(std::move(coin));
            }
            cppCoverSetData.cover_set_representation = std::vector<unsigned char>(cover_set_data_all[i].cover_set_representation, cover_set_data_all[i].cover_set_representation + cover_set_data_all[i].cover_set_representationLength);
            cppCoverSetDataAll[cover_set_data_all[i].setId] = std::move(cppCoverSetData);
        }

        std::map<uint64_t, uint256> cppIdAndBlockHashesAll;
        for (int i = 0; i < idAndBlockHashesLength; i++) {
            std::vector<unsigned char> vec(idAndBlockHashes[i].hash, idAndBlockHashes[i].hash + 32);
            cppIdAndBlockHashesAll[idAndBlockHashes[i].id] = uint256(vec);
        }

        std::vector<unsigned char> vec(txHashSig, txHashSig + 32);
        uint256 cppTxHashSig = uint256(vec);
        std::vector<unsigned char> extensionCommitmentBytes(extensionCommitment, extensionCommitment + 32);
        uint256 cppExtensionCommitment(extensionCommitmentBytes);
        auto cppSpendVersion = static_cast<spark::SpendTransactionVersion>(spendVersion);

        // Output data
        std::vector<uint8_t> cppSerializedSpend;
        CAmount cppFee;
        std::vector<std::vector<unsigned char>> cppOutputScripts;

        // used coins
        std::vector<CSparkMintMeta> spentCoinsOut;

        // Call spark::createSparkSpendTransaction.
        createSparkSpendTransaction(
            spendKey,
            fullViewKey,
            incomingViewKey,
            cppRecipients,
            cppPrivateRecipients,
            std::move(cppCoins),
            cppCoverSetDataAll,
            cppIdAndBlockHashesAll,
            cppTxHashSig,
            additionalTxSize,
            cppSpendVersion,
            cppExtensionCommitment,
            cppFee,
            cppSerializedSpend,
            cppOutputScripts,
            spentCoinsOut
        );

        std::unique_ptr<SparkSpendTransactionResult, decltype(&freeSpendResult)> result(
            allocate<SparkSpendTransactionResult>(), freeSpendResult);
        result->isError = false;
        result->fee = cppFee;

        result->usedCoinsLength = spentCoinsOut.size();
        result->usedCoins = allocate<UsedCoin>(result->usedCoinsLength);
        for (int i = 0; i < result->usedCoinsLength; i++) {
            result->usedCoins[i].height = spentCoinsOut[i].nHeight;
            result->usedCoins[i].groupId = spentCoinsOut[i].nId;

            CDataStream coinStream(SER_NETWORK, PROTOCOL_VERSION);
            coinStream << spentCoinsOut[i].coin;
            result->usedCoins[i].serializedCoin = allocate<CCDataStream>();
            result->usedCoins[i].serializedCoin->length = coinStream.size();
            result->usedCoins[i].serializedCoin->data = copyBytes(coinStream.data(), coinStream.size());

            result->usedCoins[i].serializedCoinContext = allocate<CCDataStream>();
            result->usedCoins[i].serializedCoinContext->length = spentCoinsOut[i].serial_context.size();
            result->usedCoins[i].serializedCoinContext->data = copyBytes(
                spentCoinsOut[i].serial_context.data(), spentCoinsOut[i].serial_context.size());
        }

        result->outputScriptsLength = cppOutputScripts.size();
        result->outputScripts = allocate<OutputScript>(result->outputScriptsLength);
        for (int i = 0; i < result->outputScriptsLength; i++) {
            result->outputScripts[i].length = cppOutputScripts[i].size();
            result->outputScripts[i].bytes = copyBytes(cppOutputScripts[i].data(), cppOutputScripts[i].size());
        }

        result->dataLength = cppSerializedSpend.size();
        result->data = copyBytes(cppSerializedSpend.data(), cppSerializedSpend.size());

        return result.release();
    } catch (const std::exception& e) {
        auto* result = static_cast<SparkSpendTransactionResult*>(calloc(1, sizeof(SparkSpendTransactionResult)));
        if (!result) return fail("Out of memory");
        result->isError = true;
        result->dataLength = strlen(e.what());
        result->data = (unsigned char*)malloc(sizeof(unsigned char) * result->dataLength);
        if (!result->data) {
            free(result);
            return fail("Out of memory");
        }
        memcpy(result->data, e.what(), result->dataLength);

        return result;
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
SerializedMintContextResult* serializeMintContext(
        DartInputData* inputs,
        int inputsLength
) {
    try {
        if (inputsLength < 0 || (inputsLength > 0 && !inputs)) return fail("Mint context inputs are required");
        CDataStream serialContextStream(SER_NETWORK, PROTOCOL_VERSION);
        for (int i = 0; i < inputsLength; i++) {
            if (!inputs[i].txHash || inputs[i].txHashLength != 32) return fail("Transaction hashes must be 32 bytes");
            std::vector<unsigned char> vec(inputs[i].txHash, inputs[i].txHash + inputs[i].txHashLength);
            CTxIn input(
                    uint256(vec),
                    inputs[i].vout,
                    CScript(),
                    std::numeric_limits<unsigned int>::max() - 1);
            input.scriptSig = CScript();
            input.scriptWitness.SetNull();
            serialContextStream << input;
        }
        std::unique_ptr<SerializedMintContextResult, decltype(&free)> result(
            allocate<SerializedMintContextResult>(), free);
        result->contextLength = serialContextStream.size();
        result->context = copyBytes(serialContextStream.data(), serialContextStream.size());
        return result.release();
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
ValidateAddressResult* isValidSparkAddress(
        const char* addressCStr,
        int isTestNet
) {
    auto* result = static_cast<ValidateAddressResult*>(calloc(1, sizeof(ValidateAddressResult)));
    if (!result) return fail("Out of memory");
    try {
        if (!addressCStr) throw std::invalid_argument("Invalid address");
        spark::Address address;
        std::string addressString(addressCStr);
        unsigned char network = address.decode(addressString);
        result->isValid = network == (isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);
        result->errorMessage = nullptr;
        return result;
    } catch (const std::exception& e) {
        result->errorMessage = (char*) malloc(sizeof(char) * (strlen(e.what()) + 1));
        if (!result->errorMessage) {
            free(result);
            return fail("Out of memory");
        }
        strcpy(result->errorMessage, e.what());
        return result;
    } catch (...) {
        free(result);
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
const char* hashTags(unsigned char* tags, int tagCount) {
    try {
        if (tagCount < 0 || (tagCount > 0 && !tags)) return fail("Tags are required");
        std::unique_ptr<char, decltype(&free)> result(
            allocate<char>(static_cast<size_t>(tagCount) * 64), free);
        for (int i = 0; i < tagCount; i++) {
            const unsigned char* encoded = tags + (static_cast<size_t>(i) * 34);
            if (!isCanonicalTag(encoded)) {
                return fail("Tags must encode a canonical point on the curve");
            }
            secp_primitives::GroupElement tag;
            tag.deserialize(encoded);
            std::string hex = primitives::GetLTagHash(tag).GetHex();
            memcpy(result.get() + (static_cast<size_t>(i) * 64), hex.data(), 64);
        }
        return result.release();
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
const char* hashTag(const char* x, const char* y) {
    try {
        if (!isHexCoordinate(x) || !isHexCoordinate(y)) {
            return fail("Tag coordinates must be hex values below the field prime");
        }
        secp_primitives::GroupElement tag(x, y, 16);
        if (!tag.isMember() || tag.isInfinity()) {
            return fail("Tag coordinates do not describe a point on the curve");
        }
        return copyString(primitives::GetLTagHash(tag).GetHex());
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
SparkFeeResult* estimateSparkFee(
        unsigned char* keyData,
        int index,
        int64_t sendAmount,
        int subtractFeeFromAmount,
        struct DartSpendCoinData* coins,
        int coinsLength,
        int privateRecipientsLength,
        int utxoNum,
        int additionalTxSize,
        int spendVersion
) {
    try {
        // Derive the keys from the key data and index.
        spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);
        spark::FullViewKey fullViewKey(spendKey);
        spark::IncomingViewKey incomingViewKey(fullViewKey);

        std::list<CSparkMintMeta> cppCoins;
        for (int i = 0; i < coinsLength; i++) {
            spark::Coin coin = deserializeCoin(coins[i].serializedCoin->data, coins[i].serializedCoin->length);
            std::vector<unsigned char> contextVec(coins[i].serializedCoinContext->data, coins[i].serializedCoinContext->data + coins[i].serializedCoinContext->length);
            coin.setSerialContext(contextVec);
            CSparkMintMeta meta = getMetadata(coin, incomingViewKey);
            meta.nId = coins[i].groupId;
            meta.nHeight = coins[i].height;
            meta.coin = std::move(coin);
            cppCoins.push_back(std::move(meta));
        }

        std::pair<CAmount, std::vector<CSparkMintMeta>> estimated = SelectSparkCoins(
                sendAmount,
                subtractFeeFromAmount > 0,
                std::move(cppCoins),
                privateRecipientsLength,
                utxoNum,
                additionalTxSize,
                static_cast<spark::SpendTransactionVersion>(spendVersion)
        );

        SparkFeeResult *result = allocate<SparkFeeResult>();
        result->error = nullptr;
        result->fee = estimated.first;

        return result;
    } catch (const std::exception& e) {
        SparkFeeResult *result = (SparkFeeResult*)malloc(sizeof(SparkFeeResult));
        if (!result) return fail("Out of memory");
        result->fee = 0;
        result->error = (char*)malloc(sizeof(char) * (strlen(e.what()) + 1));
        if (!result->error) {
            free(result);
            return fail("Out of memory");
        }
        strcpy(result->error, e.what());

        return result;
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
SparkNameScript* createSparkNameScript(
        int sparkNameValidityBlocks,
        const char* name,
        const char* additionalInfo,
        const unsigned char* ownershipDigest,
        int spendVersion,
        unsigned char* spendKeyData,
        int spendKeyIndex,
        int diversifier,
        int isTestNet,
        int hashFailSafe,
        int withoutProof
) {
    try {
        // Derive the keys from the key data and index.
        spark::SpendKey spendKey = createSpendKeyFromData(spendKeyData, spendKeyIndex);
        spark::FullViewKey fullViewKey(spendKey);
        spark::IncomingViewKey incomingViewKey(fullViewKey);
        std::vector<unsigned char> ownershipDigestBytes(ownershipDigest, ownershipDigest + 32);
        uint256 cppOwnershipDigest(ownershipDigestBytes);
        auto cppSpendVersion = static_cast<spark::SpendTransactionVersion>(spendVersion);
        if (cppSpendVersion != spark::SpendTransactionVersion::V1 &&
            cppSpendVersion != spark::SpendTransactionVersion::V2) {
            throw std::invalid_argument("Unsupported Spark spend version");
        }

        std::string nameString(name);
        std::string infoString(additionalInfo);

        spark::CSparkNameTxData nameTxData;
        nameTxData.name = nameString;
        nameTxData.sparkAddress = getAddress(incomingViewKey, diversifier).encode(isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);
        nameTxData.sparkNameValidityBlocks = static_cast<uint32_t>(sparkNameValidityBlocks);
        nameTxData.additionalInfo = infoString;
        nameTxData.hashFailsafe = hashFailSafe;

        std::vector<unsigned char> outputScript;
        if (withoutProof) {
            outputScript.clear();
            nameTxData.addressOwnershipProof.clear();
            CDataStream sparkNameDataStream(SER_NETWORK, PROTOCOL_VERSION);
            sparkNameDataStream << nameTxData;
            outputScript.insert(outputScript.end(), sparkNameDataStream.begin(), sparkNameDataStream.end());
        } else {
            if (cppSpendVersion == spark::SpendTransactionVersion::V1) {
                try {
                    getSparkNameOwnershipMessage(cppOwnershipDigest, cppSpendVersion);
                } catch (const std::exception&) {
                    SparkNameScript* result = (SparkNameScript*)malloc(sizeof(SparkNameScript));
                    if (!result) return fail("Out of memory");

                    const char* error = "hash fail";

                    result->script = nullptr;
                    result->scriptLength = 0;
                    result->size = 0;
                    result->error = (char*)malloc(strlen(error) + 1);
                    if (!result->error) {
                        free(result);
                        return fail("Out of memory");
                    }
                    strcpy(result->error, error);

                    return result;
                }
            }
            GetSparkNameScript(
                nameTxData,
                cppOwnershipDigest,
                cppSpendVersion,
                spendKey,
                incomingViewKey,
                outputScript);
        }

        std::size_t sparkNameTxDataSize = getSparkNameTxDataSize(nameTxData);

        SparkNameScript* result = (SparkNameScript*)malloc(sizeof(SparkNameScript));
        if (!result) return fail("Out of memory");

        result->scriptLength = outputScript.size();
        result->error = nullptr;
        result->script = (unsigned char*)malloc(outputScript.size());
        result->size = sparkNameTxDataSize;
        if (!result->script) {
            free(result);
            return fail("Out of memory");
        }

        memcpy(result->script, outputScript.data(), outputScript.size());

        return result;
    } catch (const std::exception& e) {
        SparkNameScript* result = (SparkNameScript*)malloc(sizeof(SparkNameScript));
        if (!result) return fail("Out of memory");

        result->script = nullptr;
        result->scriptLength = 0;
        result->size = 0;
        result->error = (char*)malloc(strlen(e.what()) + 1);
        if (result->error) {
            strcpy(result->error, e.what());
        } else {
            free(result);
            return fail("Out of memory");
        }

        return result;
    } catch (...) {
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
        SparkNameCommitmentResult* cGetSparkNameCommitment(
        const unsigned char* serializedSparkNameData,
        int serializedSparkNameDataLength
) {
    SparkNameCommitmentResult* result =
    (SparkNameCommitmentResult*)malloc(sizeof(SparkNameCommitmentResult));
    if (!result) return fail("Out of memory");

    result->commitment = nullptr;
    result->commitmentLength = 0;
    result->error = nullptr;

    try {
        if (!serializedSparkNameData || serializedSparkNameDataLength <= 0) {
            throw std::invalid_argument(
                    "Serialized Spark Name data must not be empty");
        }

        const char* serialized = reinterpret_cast<const char*>(serializedSparkNameData);
        CDataStream stream(serialized, serialized + serializedSparkNameDataLength,
                           SER_NETWORK, PROTOCOL_VERSION);
        spark::CSparkNameTxData nameTxData;
        stream >> nameTxData;
        if (!stream.empty()) {
            throw std::invalid_argument(
                    "Serialized Spark Name data contains trailing bytes");
        }

        const uint256 commitment = getSparkNameCommitment(nameTxData);
        result->commitmentLength = commitment.size();
        result->commitment =
                (unsigned char*)malloc(result->commitmentLength);
        if (!result->commitment) {
            free(result);
            return fail("Out of memory");
        }

        memcpy(
                result->commitment,
                commitment.begin(),
                result->commitmentLength);
        return result;
    } catch (const std::exception& e) {
        result->error = (char*)malloc(strlen(e.what()) + 1);
        if (!result->error) {
            free(result);
            return fail("Out of memory");
        }
        strcpy(result->error, e.what());
        return result;
    } catch (...) {
        free(result->commitment);
        free(result);
        return failWithException();
    }
}

FFI_PLUGIN_EXPORT
char* native_last_error(void) {
    if (!lastError[0]) return nullptr;
    char* message = static_cast<char*>(malloc(strlen(lastError) + 1));
    if (message) strcpy(message, lastError);
    lastError[0] = '\0';
    return message;
}

FFI_PLUGIN_EXPORT
void native_free(void* ptr) {
    free(ptr);
}

#ifdef __cplusplus
}
#endif
