#include "flutter_libsparkmobile.h"
#include "utils.h"
#include "deps/sparkmobile/include/spark.h"
#include "deps/sparkmobile/src/spark.h"
#include "deps/sparkmobile/src/sparkname.h"
#include "deps/sparkmobile/bitcoin/uint256.h"
#include "structs.h"
#include "transaction.h"
#include "deps/sparkmobile/bitcoin/script.h"  // For CScript.

#include <cstring>
#include <iostream> // Just for printing.

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
        // Use the hex string directly to create the SpendKey.
        spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);

        spark::FullViewKey fullViewKey(spendKey);
        spark::IncomingViewKey incomingViewKey(fullViewKey);
        spark::Address address(incomingViewKey, static_cast<uint64_t>(diversifier));

        // Encode the Address object into a string using the appropriate network.
        std::string encodedAddress = address.encode(isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);

        // Allocate memory for the C-style string.
        char* cstr = new char[encodedAddress.length() + 1];
        std::strcpy(cstr, encodedAddress.c_str());

        return cstr;
    } catch (const std::exception& e) {
        std::cerr << "Exception: " << e.what() << std::endl;
        return nullptr;
    }
}

/*
 * FFI-friendly wrapper for spark:identifyCoin.
 *
 * identifyCoin: https://github.com/firoorg/sparkmobile/blob/8bf17cd3deba6c3b0d10e89282e02936d7e71cdd/src/spark.cpp#L400
 */
//FFI_PLUGIN_EXPORT
//CIdentifiedCoinData identifyCoin(const unsigned char* serializedCoin, int serializedCoinLength, unsigned char* keyData, int index) {
//    try {
//        spark::Coin coin = deserializeCoin(serializedCoin, serializedCoinLength);
//
//        // Derive the incoming view key from the key data and index.
//        spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);
//        spark::FullViewKey fullViewKey(spendKey);
//        spark::IncomingViewKey incomingViewKey(fullViewKey);
//
//        spark::IdentifiedCoinData identifiedCoinData = coin.identify(incomingViewKey);
//        return toFFI(identifiedCoinData);
//    } catch (const std::exception& e) {
//        std::cerr << "Exception: " << e.what() << std::endl;
//        return CIdentifiedCoinData();
//    }
//}

FFI_PLUGIN_EXPORT
AggregateCoinData* idAndRecoverCoin(
        const unsigned char* serializedCoin,
        int serializedCoinLength,
        unsigned char* keyData,
        int index,
        unsigned char* context,
        int contextLength,
        int isTestNet) {
    try {
        spark::Coin coin = deserializeCoin(serializedCoin, serializedCoinLength);

        std::vector<unsigned char> contextVec(context, context + contextLength);
        coin.setSerialContext(contextVec);

        // Derive the incoming view key from the key data and index.
        spark::SpendKey spendKey = createSpendKeyFromData(keyData, index);
        spark::FullViewKey fullViewKey(spendKey);
        spark::IncomingViewKey incomingViewKey(fullViewKey);

        spark::IdentifiedCoinData identifiedCoinData = coin.identify(incomingViewKey);

        spark::RecoveredCoinData data = coin.recover(fullViewKey, identifiedCoinData);

        spark::Address address = getAddress(incomingViewKey, identifiedCoinData.i);
        std::string addressString = address.encode(isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);

        AggregateCoinData* result = (AggregateCoinData*)malloc(sizeof(AggregateCoinData));

        result->type = coin.type;
        result->diversifier = identifiedCoinData.i;
        result->value = identifiedCoinData.v;

        result->address = (char*)malloc((addressString.length() + 1) * sizeof(char));
        std::strcpy(result->address, addressString.c_str());

        result->memo = (char*)malloc((identifiedCoinData.memo.length() + 1) * sizeof(char));
        std::strcpy(result->memo, identifiedCoinData.memo.c_str());

        uint256 lTagHash = primitives::GetLTagHash(data.T);
        result->lTagHash = (char*)malloc((lTagHash.GetHex().length() + 1) * sizeof(char));
        std::strcpy(result->lTagHash, lTagHash.GetHex().c_str());

        result->encryptedDiversifier = (unsigned char*)malloc(identifiedCoinData.d.size() * sizeof(unsigned char));
        result->encryptedDiversifierLength = identifiedCoinData.d.size();
        memcpy(result->encryptedDiversifier,identifiedCoinData.d.data(),identifiedCoinData.d.size() * sizeof(unsigned char));

        result->nonceHexLength = identifiedCoinData.k.GetHex().length();
        result->nonceHex = (char*)malloc(sizeof(char) * result->nonceHexLength);
        memcpy(result->nonceHex, identifiedCoinData.k.GetHex().c_str(), sizeof(char) * result->nonceHexLength);

        result->serial = (unsigned char*)malloc(data.s.GetHex().length() * sizeof(unsigned char));
        result->serialLength = data.s.GetHex().length();
        memcpy(result->serial,data.s.GetHex().c_str(),data.s.GetHex().length() * sizeof(unsigned char));

        return result;
    } catch (const std::exception& e) {
//        std::cerr << "Exception: " << e.what() << std::endl;
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
    // Construct vector of spark::MintedCoinData.
    std::vector<spark::MintedCoinData> outputs;

    // Copy the data from the array to the vector.
    for (int i = 0; i < outputsLength; i++) {
        spark::MintedCoinData data;
        data.memo = cOutputs[i].memo;
        data.address = decodeAddress(cOutputs[i].address);
        data.v = cOutputs[i].value;
        outputs.push_back(data);
    }

    // Construct vector of unsigned chars.
    std::vector<unsigned char> serialVec(serial_context, serial_context + serial_contextLength);

    // Call spark::createSparkMintRecipients.
    std::vector<CRecipient> recipients = createSparkMintRecipients(outputs, serialVec, generate);

    // Create a CRecipient* array.
    CCRecipientList *data = (CCRecipientList*)malloc(sizeof(CCRecipientList));
    data->length = recipients.size();
    data->list = (CCRecipient*)malloc(sizeof(CCRecipient) * recipients.size());

    // Copy the data from the vector to the array.
    for (int i = 0; i < recipients.size(); i++) {
        data->list[i].cAmount = recipients[i].amount;
        data->list[i].subtractFee = recipients[i].subtractFeeFromAmount;
        data->list[i].pubKeyLength = recipients[i].pubKey.size();
        data->list[i].pubKey = (unsigned char*)malloc(sizeof(unsigned char) * recipients[i].pubKey.size());
        std::vector<unsigned char> vec(recipients[i].pubKey.begin(), recipients[i].pubKey.end());
        unsigned char* ptr = vec.data();
        for (int j = 0; j < data->list[i].pubKeyLength; j++) {
            data->list[i].pubKey[j] = ptr[j];
        }
    }

    // Return the array.
    return data;
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
    int additionalTxSize
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
            cppFee,
            cppSerializedSpend,
            cppOutputScripts,
            spentCoinsOut
        );

        SparkSpendTransactionResult *result = (SparkSpendTransactionResult*)malloc(sizeof(SparkSpendTransactionResult));
        result->isError = false;
        result->fee = cppFee;

        result->usedCoinsLength = spentCoinsOut.size();
        result->usedCoins = (UsedCoin*)malloc(sizeof(UsedCoin) * result->usedCoinsLength);
        for (int i = 0; i < result->usedCoinsLength; i++) {
            result->usedCoins[i].height = spentCoinsOut[i].nHeight;
            result->usedCoins[i].groupId = spentCoinsOut[i].nId;

            CDataStream coinStream(SER_NETWORK, PROTOCOL_VERSION);
            coinStream << spentCoinsOut[i].coin;
            result->usedCoins[i].serializedCoin = (CCDataStream*)malloc(sizeof(CCDataStream));
            result->usedCoins[i].serializedCoin->length = coinStream.size();
            result->usedCoins[i].serializedCoin->data = (unsigned char*)malloc(result->usedCoins[i].serializedCoin->length);
            memcpy(result->usedCoins[i].serializedCoin->data, coinStream.data(), result->usedCoins[i].serializedCoin->length);

            result->usedCoins[i].serializedCoinContext = (CCDataStream*)malloc(sizeof(CCDataStream));
            result->usedCoins[i].serializedCoinContext->length = spentCoinsOut[i].serial_context.size();
            result->usedCoins[i].serializedCoinContext->data = (unsigned char*)malloc(result->usedCoins[i].serializedCoinContext->length);
            memcpy(result->usedCoins[i].serializedCoinContext->data, spentCoinsOut[i].serial_context.data(), result->usedCoins[i].serializedCoinContext->length);
        }

        result->outputScriptsLength = cppOutputScripts.size();
        result->outputScripts = (OutputScript*)malloc(sizeof(OutputScript) * result->outputScriptsLength);
        for (int i = 0; i < result->outputScriptsLength; i++) {
            result->outputScripts[i].length = cppOutputScripts[i].size();
            result->outputScripts[i].bytes = (unsigned char*)malloc(result->outputScripts[i].length);
            memcpy(result->outputScripts[i].bytes, cppOutputScripts[i].data(), result->outputScripts[i].length);
        }

        result->dataLength = cppSerializedSpend.size();
        result->data = (unsigned char*)malloc(result->dataLength);
        memcpy(result->data, cppSerializedSpend.data(), result->dataLength);

        return result;
    } catch (const std::exception& e) {
        SparkSpendTransactionResult *result = (SparkSpendTransactionResult*)malloc(sizeof(SparkSpendTransactionResult));
        result->isError = true;
        result->dataLength = strlen(e.what());
        result->data = (unsigned char*)malloc(sizeof(unsigned char) * result->dataLength);
        memcpy(result->data, e.what(), result->dataLength);

        return result;
    }
}

FFI_PLUGIN_EXPORT
SerializedMintContextResult* serializeMintContext(
        DartInputData* inputs,
        int inputsLength
) {
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

    SerializedMintContextResult* result = (SerializedMintContextResult*)malloc(sizeof(SerializedMintContextResult));
    result->contextLength = serialContextStream.size();
    result->context = (unsigned char*) malloc(sizeof(unsigned char) * serialContextStream.size());
    memcpy(result->context, serialContextStream.data(), sizeof(unsigned char) * serialContextStream.size());
    return result;
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
        int additionalTxSize
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
                additionalTxSize
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
        const char* scalarMHex,
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

        std::string nameString(name);
        std::string infoString(additionalInfo);

        spark::CSparkNameTxData nameTxData;
        nameTxData.name = nameString;
        nameTxData.sparkAddress = getAddress(incomingViewKey, diversifier).encode(isTestNet ? spark::ADDRESS_NETWORK_TESTNET : spark::ADDRESS_NETWORK_MAINNET);
        nameTxData.sparkNameValidityBlocks = static_cast<uint32_t>(sparkNameValidityBlocks);
        nameTxData.additionalInfo = infoString;
        nameTxData.hashFailsafe = hashFailSafe;

        // result
        std::vector<unsigned char> outputScript;
        if (withoutProof) {
            outputScript.clear();
            nameTxData.addressOwnershipProof.clear();
            CDataStream sparkNameDataStream(SER_NETWORK, PROTOCOL_VERSION);
            sparkNameDataStream << nameTxData;
            outputScript.insert(outputScript.end(), sparkNameDataStream.begin(), sparkNameDataStream.end());
        } else {
            std::string mHex(scalarMHex);
            Scalar m;
            try {
                m.SetHex(mHex);
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
            GetSparkNameScript(nameTxData, m, spendKey, incomingViewKey, outputScript);
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
void native_free(void* ptr) {
    free(ptr);
}

#ifdef __cplusplus
}
#endif