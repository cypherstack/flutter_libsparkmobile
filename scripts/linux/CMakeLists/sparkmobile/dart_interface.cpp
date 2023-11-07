#include "../include/spark.h"
#include "utils.h"
#include <cstring>
#include <iostream> // Just for printing.

using namespace spark;

/// Generate a new spend key and cast it to and FFI-friendly string.
extern "C" __attribute__((visibility("default"))) __attribute__((used))
const char * generateSpendKey() {
    try {
        // Use the default (deployment) parameters.
        const spark::Params *params = spark::Params::get_default();

        // Generate a new SpendKey.
        spark::SpendKey key(params);

        // Instead of just returning the SpendKey, we need to cast it to an FFI-friendly string.
        // The r value is used to create a SpendKey.  Use get_r to get the r value.
        const secp_primitives::Scalar &r = key.get_r();

        // Allocate a buffer of the required size.
        unsigned char serialized_r_buffer[32]; // Assuming size is 32, adjust if necessary

        // Pass this buffer to the r.serialize() method.
        r.serialize(serialized_r_buffer);

        // Fill the std::vector<unsigned char> with the serialized data.
        std::vector<unsigned char> serialized_r(serialized_r_buffer,
                                                serialized_r_buffer + sizeof(serialized_r_buffer));

        // Cast the serialized r value to an FFI-friendly string.
        const char *serialized_r_str = bin2hex(serialized_r.data(), serialized_r.size());

        // Return the serialized r value.
        return serialized_r_str;
    } catch (const std::exception& e) {
        // If an exception is thrown, print it to the console.
        std::cout << "Exception: " << e.what() << "\n";

        // Return the error message.
        return e.what();
    }
}

/*
extern "C" __attribute__((visibility("default"))) __attribute__((used))
const char * create_spend_key(const unsigned char keydata[32], const int32_t index) {
    spark::SpendKeyData keyData(keydata, index);
    spark::SpendKey key = createSpendKey(keyData);

    return key;
}
*/
