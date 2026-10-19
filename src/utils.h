#ifndef ORG_FIRO_SPARK_UTILS_H
#define ORG_FIRO_SPARK_UTILS_H

#include <string>

#include "deps/sparkmobile/include/spark.h"

spark::SpendKey createSpendKeyFromData(unsigned char *keyData, int index);

spark::Address decodeAddress(const std::string& str);

spark::Coin deserializeCoin(const unsigned char *serializedCoin, int length);

#endif //ORG_FIRO_SPARK_UTILS_H
