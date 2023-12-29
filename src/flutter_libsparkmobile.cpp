#include "flutter_libsparkmobile.h"
#include "utils.h"
#include "deps/sparkmobile/include/spark.h"
#include "deps/sparkmobile/src/spark.h"
#include "deps/sparkmobile/bitcoin/uint256.h"
#include "structs.h"
#include "transaction.h"
#include "deps/sparkmobile/bitcoin/script.h"  // For CScript.

#include <cstring>
#include <iostream> // Just for printing.

using namespace spark;

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
    unsigned char* txHashSig
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
            cppFee,
            cppSerializedSpend,
            cppOutputScripts
        );

        SparkSpendTransactionResult *result = (SparkSpendTransactionResult*)malloc(sizeof(SparkSpendTransactionResult));
        result->isError = false;
        result->fee = cppFee;

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
GetSparkCoinsResult* getCoinsToSpend(int64_t spendAmount, CCSparkMintMeta* coins, int coinsLength) {
    try {
        std::vector<CSparkMintMeta> coinsToSpend_out;
        int64_t change;

        std::list<CSparkMintMeta> _coins;

        for (int i = 0; i < coinsLength; i++) {
            CSparkMintMeta meta;
            meta.nHeight = coins[i].height;
            meta.nId = coins[i].id;
            meta.isUsed = coins[i].isUsed > 0;
            meta.txid = uint256S((const char*)coins[i].txid);
            meta.i = coins[i].i;
            meta.d = std::vector<unsigned char>(coins[i].d, coins[i].d + coins[i].dLength);
            meta.v = coins[i].v;
            Scalar k;
            k.SetHex(std::string(coins[i].nonceHex, coins[i].nonceHexLength));
            meta.k = k;
            meta.memo = std::string(coins[i].memo, coins[i].memoLength);
            meta.serial_context = std::vector<unsigned char>(coins[i].serial_context, coins[i].serial_context + coins[i].serial_contextLength);
            meta.type = coins[i].type;
            meta.coin = deserializeCoin(coins[i].serializedCoin, coins[i].serializedCoinLength);

            _coins.push_back(meta);
        }

        CAmount _amount = spendAmount;
        GetCoinsToSpend(_amount, coinsToSpend_out, _coins, change);

        GetSparkCoinsResult* result = (GetSparkCoinsResult*)malloc(sizeof(GetSparkCoinsResult));
        result->changeToMint = change;
        result->length = coinsToSpend_out.size();
        result->list = (CCSparkMintMeta*)malloc(sizeof(CCSparkMintMeta) * result->length);

        for (int i = 0; i < coinsToSpend_out.size(); i++) {
            result->list[i].height = coinsToSpend_out[i].nHeight;

            result->list[i].id = coinsToSpend_out[i].nId;

            result->list[i].isUsed = coinsToSpend_out[i].isUsed;

            result->list[i].txid = (unsigned char*)malloc(sizeof(unsigned char*) * coinsToSpend_out[i].txid.size());
            memcpy(result->list[i].txid, coinsToSpend_out[i].txid.begin(), sizeof(unsigned char) * coinsToSpend_out[i].txid.size());

            result->list[i].i = coinsToSpend_out[i].i;

            result->list[i].dLength = coinsToSpend_out[i].d.size();
            result->list[i].d = (unsigned char*)malloc(sizeof(unsigned char) * coinsToSpend_out[i].d.size());
            memcpy(result->list[i].d, coinsToSpend_out[i].d.data(), sizeof(unsigned char) * coinsToSpend_out[i].d.size());

            result->list[i].v = coinsToSpend_out[i].v;

            result->list[i].nonceHexLength = coinsToSpend_out[i].k.GetHex().length();
            result->list[i].nonceHex = (char*)malloc(sizeof(char) * result->list[i].nonceHexLength);
            memcpy(result->list[i].nonceHex, coinsToSpend_out[i].k.GetHex().c_str(), sizeof(char) * result->list[i].nonceHexLength);

            result->list[i].memoLength = coinsToSpend_out[i].memo.length();
            result->list[i].memo = (char*)malloc(sizeof(char) * result->list[i].memoLength);
            memcpy(result->list[i].memo, coinsToSpend_out[i].memo.c_str(), sizeof(char) * result->list[i].memoLength);


            result->list[i].serial_context = (unsigned char*)malloc(sizeof(unsigned char) * coinsToSpend_out[i].serial_context.size());
            memcpy(result->list[i].serial_context, coinsToSpend_out[i].serial_context.data(), sizeof(unsigned char) * coinsToSpend_out[i].serial_context.size());
            result->list[i].serial_contextLength = coinsToSpend_out[i].serial_context.size();

            CDataStream coinStream(SER_NETWORK, PROTOCOL_VERSION);
            coinStream << coinsToSpend_out[i].coin;
            result->list[i].serializedCoinLength = coinStream.size();
            result->list[i].serializedCoin = (unsigned char*)malloc(sizeof(unsigned char) * coinStream.size());
            memcpy(result->list[i].serializedCoin, coinStream.data(), coinStream.size());

            result->list[i].type = coinsToSpend_out[i].type;
        }
        result->errorMessageLength = 0; // false/no error
        return result;
    } catch (const std::exception& e) {
        GetSparkCoinsResult *result = (GetSparkCoinsResult*)malloc(sizeof(GetSparkCoinsResult));
        result->errorMessageLength = strlen(e.what());
        result->errorMessage = (char*)malloc(sizeof(char) * result->errorMessageLength);
        memcpy(result->errorMessage, e.what(), result->errorMessageLength);

        return result;
    }
}

FFI_PLUGIN_EXPORT
SelectSparkCoinsResult* selectSparkCoins(
        int64_t required,
        int subtractFeeFromAmount,
        CCSparkMintMeta* coins,
        int coinsLength,
        int mintNum
) {
    try {
        std::list<CSparkMintMeta> _coins;
        for (int i = 0; i < coinsLength; i++) {
            for (int i = 0; i < coinsLength; i++) {
                CSparkMintMeta meta;
                meta.nHeight = coins[i].height;
                meta.nId = coins[i].id;
                meta.isUsed = coins[i].isUsed > 0;
                meta.txid = uint256S((const char*)coins[i].txid);
                meta.i = coins[i].i;
                meta.d = std::vector<unsigned char>(coins[i].d, coins[i].d + coins[i].dLength);
                meta.v = coins[i].v;
                Scalar k;
                k.SetHex(std::string(coins[i].nonceHex, coins[i].nonceHexLength));
                meta.k = k;
                meta.memo = std::string(coins[i].memo, coins[i].memoLength);
                meta.serial_context = std::vector<unsigned char>(coins[i].serial_context, coins[i].serial_context + coins[i].serial_contextLength);
                meta.type = coins[i].type;
                meta.coin = deserializeCoin(coins[i].serializedCoin, coins[i].serializedCoinLength);

                _coins.push_back(meta);
            }
        }

        std::pair<CAmount, std::vector<CSparkMintMeta>> estimated = SelectSparkCoins(required, subtractFeeFromAmount > 0, _coins, mintNum);

        SelectSparkCoinsResult* result = (SelectSparkCoinsResult*)malloc(sizeof(SelectSparkCoinsResult));
        result->length = estimated.second.size();
        result->fee = estimated.first;
        result->list = (CCSparkMintMeta*)malloc(sizeof(CCSparkMintMeta) * result->length);

        for (int i = 0; i < estimated.second.size(); i++) {
            result->list[i].height = estimated.second[i].nHeight;

            result->list[i].id = estimated.second[i].nId;

            result->list[i].isUsed = estimated.second[i].isUsed;

            result->list[i].txid = (unsigned char*)malloc(sizeof(unsigned char) * estimated.second[i].txid.size());
            memcpy(result->list[i].txid, estimated.second[i].txid.begin(), sizeof(unsigned char) * estimated.second[i].txid.size());

            result->list[i].i = estimated.second[i].i;

            result->list[i].dLength = estimated.second[i].d.size();
            result->list[i].d = (unsigned char*)malloc(sizeof(unsigned char) * estimated.second[i].d.size());
            memcpy(result->list[i].d, estimated.second[i].d.data(), sizeof(unsigned char) * estimated.second[i].d.size());

            result->list[i].v = estimated.second[i].v;

            result->list[i].nonceHexLength = estimated.second[i].k.GetHex().length();
            result->list[i].nonceHex = (char*)malloc(sizeof(char) * result->list[i].nonceHexLength);
            memcpy(result->list[i].nonceHex, estimated.second[i].k.GetHex().c_str(), sizeof(char) * result->list[i].nonceHexLength);

            result->list[i].memoLength = estimated.second[i].memo.length();
            result->list[i].memo = (char*)malloc(sizeof(char) * result->list[i].memoLength);
            memcpy(result->list[i].memo, estimated.second[i].memo.c_str(), sizeof(char) * result->list[i].memoLength);


            result->list[i].serial_context = (unsigned char*)malloc(sizeof(unsigned char) * estimated.second[i].serial_context.size());
            memcpy(result->list[i].serial_context, estimated.second[i].serial_context.data(), sizeof(unsigned char) * estimated.second[i].serial_context.size());
            result->list[i].serial_contextLength = estimated.second[i].serial_context.size();

            CDataStream coinStream(SER_NETWORK, PROTOCOL_VERSION);
            coinStream << estimated.second[i].coin;
            result->list[i].serializedCoinLength = coinStream.size();
            result->list[i].serializedCoin = (unsigned char*)malloc(sizeof(unsigned char) * coinStream.size());
            memcpy(result->list[i].serializedCoin, coinStream.data(), coinStream.size());

            result->list[i].type = estimated.second[i].type;
        }
        result->errorMessageLength = 0; // false/no error
        return result;
    } catch (const std::exception& e) {
        SelectSparkCoinsResult *result = (SelectSparkCoinsResult*)malloc(sizeof(SelectSparkCoinsResult));
        result->errorMessageLength = strlen(e.what());
        result->errorMessage = (char*)malloc(sizeof(char) * result->errorMessageLength);
        memcpy(result->errorMessage, e.what(), result->errorMessageLength);

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
    char* result = (char*) malloc(sizeof(char) * hex.length());
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
        int privateRecipientsLength
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
                privateRecipientsLength
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