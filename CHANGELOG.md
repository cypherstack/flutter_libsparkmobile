## Unreleased

* Fix memory leaks and unsafe frees across the FFI boundary.
* Validate arguments, hashes, tags, and hex strings before native calls.
* Keep private keys and other hex input out of exception messages.
* Preserve memo bytes and recover unsigned coin values and diversifiers.
* Report the native reason when a call fails instead of a generic message.
* Treat coins that cannot be parsed as foreign, and throw when recovering a coin fails.
* Honor logging level filters.
* Include the Spark CMake files in published packages.
* Remove the unused native `idAndRecoverCoin` export.

## 0.2.0

* Adopt native assets build hooks and update Flutter dependencies.
* Support Chaum spend versions and address ownership proofs.
