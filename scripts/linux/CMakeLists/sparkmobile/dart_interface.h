#ifndef ORG_FIRO_SPARK_DART_INTERFACE_H
#define ORG_FIRO_SPARK_DART_INTERFACE_H

#include "../include/spark.h"

// TODO add param for params, eg default/test, to all functions.
const char *generateSpendKey();
const char *createSpendKey(const char * r);
const char *createFullViewKey(const char * spend_key_r);

#endif //ORG_FIRO_SPARK_DART_INTERFACE_H
