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
#include <cstdlib>
#include <cstring>
#include <memory>
#include <iostream> // Just for printing.

namespace {

template<typename T>
T* allocate(size_t count = 1) {
    auto* result = static_cast<T*>(calloc(count ? count : 1, sizeof(T)));
    if (!result) throw std::bad_alloc();
    return result;
}

unsigned char* copyBytes(const void* source, size_t length) {
    auto* result = allocate<unsigned char>(length);
    if (length) memcpy(result, source, length);
    return result;
}

char* copyString(const std::string& value) {
    auto* result = allocate<char>(value.size() + 1);
    memcpy(result, value.data(), value.size());
    return result;
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
    // Use the hex string directly to create the SpendKey.
    spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);

    spark::FullViewKey fullViewKey(spendKey);
    return getAddressFromFullViewKey(reinterpret_cast<void*>(&fullViewKey), index, diversifier, isTestNet);
}

FFI_PLUGIN_EXPORT
const char* getAddressFromFullViewKey(void* fullViewKeyVoid, int index, int diversifier, int isTestNet) {
    try {
        spark::IncomingViewKey incomingViewKey(*static_cast<spark::FullViewKey*>(fullViewKeyVoid));
        spark::Address address(incomingViewKey, static_cast<uint64_t>(diversifier));

        // Encode the Address object into a string using the appropriate network.
        std::string encodedAddress = address.encode(isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);

        // Allocate memory for the C-style string. This MUST be done with malloc so it can be freed with freeNative().
        char* cstr = static_cast<char*>(malloc(encodedAddress.length() + 1));
        std::strcpy(cstr, encodedAddress.c_str());

        return cstr;
    } catch (const std::exception& e) {
        std::cerr << "Exception: " << e.what() << std::endl;
        return nullptr;
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
    if (!result) return nullptr;

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
            return nullptr;
        }
        memcpy(result->proof, proofStream.data(), proofStream.size());
    } catch (const std::exception& e) {
        result->error = static_cast<char*>(malloc(strlen(e.what()) + 1));
        if (result->error) {
            strcpy(result->error, e.what());
        }
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

        std::vector<unsigned char> bytes(proofData, proofData + proofLength);
        CDataStream stream(bytes, SER_NETWORK, PROTOCOL_VERSION);
        stream >> proof;
        // Reject alternate encodings as well as truncated or trailing data.
        CDataStream canonical(SER_NETWORK, PROTOCOL_VERSION);
        canonical << proof;
        if (bytes != std::vector<unsigned char>(canonical.begin(), canonical.end())) {
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
    } catch (const std::exception&) {
        return 0;
    }
}

FFI_PLUGIN_EXPORT
void* getFullViewKeyFromPrivateKeyData(unsigned char* keyData, int index) {
    spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);
    spark::FullViewKey* fullViewKey = new spark::FullViewKey(spendKey);

    return static_cast<void*>(fullViewKey);
}

FFI_PLUGIN_EXPORT
void* deserializeFullViewKey(unsigned char* keyData, int keyDataLength) {
    try {
        if (!keyData || keyDataLength <= 0) return nullptr;
        auto fullViewKey = std::make_unique<spark::FullViewKey>(spark::Params::get_default());
        if (GetSerializeSize(*fullViewKey, SER_NETWORK, PROTOCOL_VERSION) != static_cast<size_t>(keyDataLength)) {
            return nullptr;
        }
        CDataStream stream(SER_NETWORK, PROTOCOL_VERSION);
        stream.write(reinterpret_cast<char*>(keyData), keyDataLength);
        stream >> *fullViewKey;
        return fullViewKey.release();
    } catch (...) {
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT
unsigned char* serializeFullViewKey(void* fullViewKeyVoid, int* serializedSize) {
    if (!serializedSize) return nullptr;
    *serializedSize = 0;
    try {
        if (!fullViewKeyVoid) return nullptr;
        CDataStream stream(SER_NETWORK, PROTOCOL_VERSION);
        stream << *static_cast<spark::FullViewKey*>(fullViewKeyVoid);
        auto* result = copyBytes(stream.data(), stream.size());
        *serializedSize = stream.size();
        return result;
    } catch (...) {
        return nullptr;
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
        if (!serializedCoin || serializedCoinLength <= 0 || !fullViewKeyVoid ||
            contextLength < 0 || (contextLength > 0 && !context)) return nullptr;
        spark::FullViewKey* fullViewKey = static_cast<spark::FullViewKey*>(fullViewKeyVoid);
        spark::Coin coin = deserializeCoin(serializedCoin, serializedCoinLength);

        std::vector<unsigned char> contextVec;
        if (contextLength) contextVec.assign(context, context + contextLength);
        coin.setSerialContext(contextVec);

        // Derive the incoming view key from the full view key
        spark::IncomingViewKey incomingViewKey(*fullViewKey);

        spark::IdentifiedCoinData identifiedCoinData = coin.identify(incomingViewKey);

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
        return nullptr;
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
            serial_contextLength < 0 || (serial_contextLength > 0 && !serial_context)) return nullptr;
        std::vector<spark::MintedCoinData> outputs;
        for (int i = 0; i < outputsLength; i++) {
            if (!cOutputs[i].address || cOutputs[i].memoLength < 0 ||
                (cOutputs[i].memoLength > 0 && !cOutputs[i].memo)) return nullptr;
            spark::MintedCoinData data;
            if (cOutputs[i].memoLength) data.memo.assign(cOutputs[i].memo, cOutputs[i].memoLength);
            data.address = decodeAddress(cOutputs[i].address);
            data.v = cOutputs[i].value;
            outputs.push_back(data);
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
        return nullptr;
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
        for (int i = 0; i < recipientsLength; i++) {
            cppRecipients.push_back(std::make_pair(recipients[i].amount, recipients[i].subtractFee));
        }

        // Convert COutputRecipient* privateRecipients to std::vector<std::pair<spark::OutputCoinData, bool>> cppPrivateRecipients.
        std::vector<std::pair<spark::OutputCoinData, bool>> cppPrivateRecipients;
        for (int i = 0; i < privateRecipientsLength; i++) {
            spark::OutputCoinData outputCoinData;
            outputCoinData.memo = std::string(privateRecipients[i].output->memo, privateRecipients[i].output->memoLength);
            outputCoinData.v = (uint64_t)privateRecipients[i].output->value;
            std::string addrString(privateRecipients[i].output->address, privateRecipients[i].output->addressLength);
            outputCoinData.address = decodeAddress(addrString);
            cppPrivateRecipients.push_back(std::make_pair(outputCoinData, privateRecipients[i].subtractFee));
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
            meta.coin = coin;
            cppCoins.push_back(meta);
        }

        std::unordered_map<uint64_t, spark::CoverSetData> cppCoverSetDataAll;
        for (int i = 0; i < cover_set_data_allLength; i++) {
            spark::CoverSetData cppCoverSetData;
            for (int j = 0; j < cover_set_data_all[i].cover_setLength; j++) {
                spark::Coin coin = deserializeCoin(cover_set_data_all[i].cover_set[j].data, cover_set_data_all[i].cover_set[j].length);
                cppCoverSetData.cover_set.push_back(coin);
            }
            cppCoverSetData.cover_set_representation = std::vector<unsigned char>(cover_set_data_all[i].cover_set_representation, cover_set_data_all[i].cover_set_representation + cover_set_data_all[i].cover_set_representationLength);
            cppCoverSetDataAll[cover_set_data_all[i].setId] = cppCoverSetData;
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
            cppCoins,
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
        if (!result) return nullptr;
        result->isError = true;
        result->dataLength = strlen(e.what());
        result->data = (unsigned char*)malloc(sizeof(unsigned char) * result->dataLength);
        if (!result->data) {
            free(result);
            return nullptr;
        }
        memcpy(result->data, e.what(), result->dataLength);

        return result;
    } catch (...) {
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT
SerializedMintContextResult* serializeMintContext(
        DartInputData* inputs,
        int inputsLength
) {
    try {
        if (inputsLength < 0 || (inputsLength > 0 && !inputs)) return nullptr;
        CDataStream serialContextStream(SER_NETWORK, PROTOCOL_VERSION);
        for (int i = 0; i < inputsLength; i++) {
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
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT
ValidateAddressResult* isValidSparkAddress(
        const char* addressCStr,
        int isTestNet
) {
    spark::Address address;
    ValidateAddressResult* result = (ValidateAddressResult*) malloc(sizeof(ValidateAddressResult));
    result->isValid = false;
    try {
        std::string addressString(addressCStr);
        unsigned char network = address.decode(addressString);
        result->isValid = network == (isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);
        result->errorMessage = nullptr;
        return result;
    } catch (const std::exception& e) {
        result->errorMessage = (char*) malloc(sizeof(char) * (strlen(e.what()) + 1));
        strcpy(result->errorMessage, e.what());
        return result;
    }
}

FFI_PLUGIN_EXPORT
const char* hashTags(unsigned char* tags, int tagCount) {
    char* result = (char*) malloc(sizeof(char) * 64 * tagCount);
    for (int i = 0; i < tagCount; i++) {
        secp_primitives::GroupElement tag;
        tag.deserialize(tags + (i * 34));
        uint256 hash = primitives::GetLTagHash(tag);
        std::string hex = hash.GetHex();
        memcpy(result + (i * 64), hex.c_str(), 64);
    }
    return result;
}

FFI_PLUGIN_EXPORT
const char* hashTag(const char* x, const char* y) {
    secp_primitives::GroupElement tag = secp_primitives::GroupElement(x, y, 16);
    uint256 hash = primitives::GetLTagHash(tag);
    std::string hex = hash.GetHex();
    char* result = (char*) malloc(sizeof(char) * (hex.length() + 1));
    strcpy(result, hex.c_str());
    return result;
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
            meta.coin = coin;
            cppCoins.push_back(meta);
        }

        std::pair<CAmount, std::vector<CSparkMintMeta>> estimated = SelectSparkCoins(
                sendAmount,
                subtractFeeFromAmount > 0,
                cppCoins,
                privateRecipientsLength,
                utxoNum,
                additionalTxSize,
                static_cast<spark::SpendTransactionVersion>(spendVersion)
        );

        SparkFeeResult *result = (SparkFeeResult*)malloc(sizeof(SparkFeeResult));
        result->error = nullptr;
        result->fee = estimated.first;

        return result;
    } catch (const std::exception& e) {
        SparkFeeResult *result = (SparkFeeResult*)malloc(sizeof(SparkFeeResult));
        result->fee = 0;
        result->error = (char*)malloc(sizeof(char) * (strlen(e.what()) + 1));
        strcpy(result->error, e.what());

        return result;
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
                    if (!result) return nullptr;

                    const char* error = "hash fail";

                    result->script = nullptr;
                    result->scriptLength = 0;
                    result->size = 0;
                    result->error = (char*)malloc(strlen(error) + 1);
                    if (result->error) {
                        strcpy(result->error, error);
                    }

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
        if (!result) return nullptr;

        result->scriptLength = outputScript.size();
        result->error = nullptr;
        result->script = (unsigned char*)malloc(outputScript.size());
        result->size = sparkNameTxDataSize;
        if (!result->script) {
            free(result);
            return nullptr;
        }

        memcpy(result->script, outputScript.data(), outputScript.size());

        return result;
    } catch (const std::exception& e) {
        SparkNameScript* result = (SparkNameScript*)malloc(sizeof(SparkNameScript));
        if (!result) return nullptr;

        result->script = nullptr;
        result->scriptLength = 0;
        result->size = 0;
        result->error = (char*)malloc(strlen(e.what()) + 1);
        if (result->error) {
            strcpy(result->error, e.what());
        }

        return result;
    }
}

FFI_PLUGIN_EXPORT
        SparkNameCommitmentResult* cGetSparkNameCommitment(
        const unsigned char* serializedSparkNameData,
        int serializedSparkNameDataLength
) {
    SparkNameCommitmentResult* result =
    (SparkNameCommitmentResult*)malloc(sizeof(SparkNameCommitmentResult));
    if (!result) return nullptr;

    result->commitment = nullptr;
    result->commitmentLength = 0;
    result->error = nullptr;

    try {
        if (!serializedSparkNameData || serializedSparkNameDataLength <= 0) {
            throw std::invalid_argument(
                    "Serialized Spark Name data must not be empty");
        }

        std::vector<unsigned char> serialized(
                serializedSparkNameData,
                serializedSparkNameData + serializedSparkNameDataLength);
        CDataStream stream(serialized, SER_NETWORK, PROTOCOL_VERSION);
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
            return nullptr;
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
            return nullptr;
        }
        strcpy(result->error, e.what());
        return result;
    }
}

FFI_PLUGIN_EXPORT
void native_free(void* ptr) {
    free(ptr);
}

#ifdef __cplusplus
}
#endif
