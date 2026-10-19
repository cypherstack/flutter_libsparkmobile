#include "utils.h"

#include "deps/sparkmobile/bitcoin/streams.h"
#include "deps/sparkmobile/src/coin.h"

spark::SpendKey createSpendKeyFromData(unsigned char *keyData, int index) {
    SpendKeyData data(keyData, index);
    return createSpendKey(data);
}

spark::Address decodeAddress(const std::string& str) {
    spark::Address address;
    address.decode(str);
    return address;
}

spark::Coin deserializeCoin(const unsigned char *serializedCoin, int length) {
    const char* bytes = reinterpret_cast<const char*>(serializedCoin);
    CDataStream stream(bytes, bytes + length, SER_NETWORK, PROTOCOL_VERSION);
    spark::Coin coin(spark::Params::get_default());
    stream >> coin;
    return coin;
}
